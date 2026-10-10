import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failure.dart';
import '../../../reminders/presentation/providers/notification_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Runs once, right after first successful signup/login. The router
/// (see app/router.dart) sends any signed-in user whose profile has
/// `onboarding_done = false` here, and away again automatically the
/// when the final step marks it done — no manual navigation needed.
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  int _step = 0;
  bool? _wantsGym;
  bool _finishing = false;
  bool _profileInitialized = false;
  DateTime? _dateOfBirth;
  String _gender = '';
  String? _nameError;
  String? _demographicError;

  static const _stepCount = 6;
  static const _genders = <String, String>{
    'woman': 'Woman',
    'man': 'Man',
    'non_binary': 'Non-binary',
    'prefer_not_to_say': 'Prefer not to say',
  };

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && _nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Please enter your name to continue.');
      return;
    }
    if (_step == 1 && _dateOfBirth == null) {
      setState(
          () => _demographicError = 'Select your date of birth to continue.');
      return;
    }
    if (_step == 2 && _gender.isEmpty) {
      setState(() => _demographicError = 'Choose one option to continue.');
      return;
    }
    _demographicError = null;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _dateOfBirth ?? DateTime(today.year - 25, today.month, today.day),
      firstDate: DateTime(today.year - 120, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Select your date of birth',
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = picked;
        _demographicError = null;
      });
    }
  }

  void _previous() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _finishing = true);
    try {
      await ref.read(profileRepositoryProvider).completeOnboarding(
            gymEnabled: _wantsGym ?? false,
            displayName: _nameController.text.trim(),
            dateOfBirth: _dateOfBirth!,
            gender: _gender,
          );
      // The router's profileProvider listener redirects to /home the
      // moment this write lands — no manual context.go needed here.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.save(e).message)));
        setState(() => _finishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    if (profile != null && !_profileInitialized) {
      _nameController.text = profile.onboardingDone ? profile.displayName : '';
      _dateOfBirth = profile.dateOfBirth;
      _gender = profile.gender ?? '';
      _profileInitialized = true;
    }
    if (profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profileAsync.hasError || profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Set up your workspace')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(profileAsync.hasError
                ? Failure.from(profileAsync.error!).message
                : 'Your profile is not available right now. Please try again.'),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: _step == 0
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Back',
                            onPressed: _finishing ? null : _previous,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_stepCount, (i) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _step ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i <= _step
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            'Step ${_step + 1} of $_stepCount',
                            key: ValueKey(_step),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _stepCount,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                itemBuilder: (context, index) {
                  final page = switch (index) {
                    0 => _NameStep(
                        controller: _nameController,
                        error: _nameError,
                        onChanged: (_) => setState(() => _nameError = null),
                        onNext: _next,
                      ),
                    1 => _AgeStep(
                        selected: _dateOfBirth,
                        error: _demographicError,
                        onPickDate: _pickDateOfBirth,
                        onNext: _next,
                      ),
                    2 => _GenderStep(
                        selected: _gender,
                        error: _demographicError,
                        onChoose: (value) => setState(() {
                          _gender = value;
                          _demographicError = null;
                        }),
                        onNext: _next,
                      ),
                    3 => _FitnessChoiceStep(
                        selected: _wantsGym,
                        onChoose: (value) {
                          setState(() => _wantsGym = value);
                          _next();
                        },
                      ),
                    4 => _NotificationsStep(onNext: _next),
                    _ => _DoneStep(finishing: _finishing, onFinish: _finish),
                  };
                  return AnimatedBuilder(
                    animation: _pageController,
                    child: page,
                    builder: (context, child) {
                      final currentPage = _pageController.hasClients
                          ? (_pageController.page ?? _step.toDouble())
                          : 0.0;
                      final distance = (currentPage - index)
                          .abs()
                          .clamp(0.0, 1.0)
                          .toDouble();
                      return Opacity(
                        opacity: 1 - distance * .25,
                        child: Transform.scale(
                          scale: 1 - distance * .025,
                          child: child,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepScaffold(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Opacity(
        opacity: ((scale - 0.92) / 0.08).clamp(0, 1).toDouble(),
        child: Transform.scale(scale: scale, child: child),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle),
                    child: Icon(icon,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 40),
                  ),
                ),
                const SizedBox(height: 24),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.error,
    required this.onChanged,
    required this.onNext,
  });

  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _StepScaffold(
        icon: Icons.waving_hand_rounded,
        title: 'What should we call you?',
        subtitle:
            'We’ll use your name around your workspace and on invoices. You can change it later in Profile.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: false,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: onChanged,
              decoration: InputDecoration(
                labelText: 'Your name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                errorText: error,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
            ),
          ],
        ),
      );
}

class _AgeStep extends StatelessWidget {
  const _AgeStep({
    required this.selected,
    required this.error,
    required this.onPickDate,
    required this.onNext,
  });

  final DateTime? selected;
  final String? error;
  final VoidCallback onPickDate;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _StepScaffold(
        icon: Icons.cake_outlined,
        title: 'When were you born?',
        subtitle:
            'Your age is calculated from your date of birth, updates each year, and cannot be edited later. Your date of birth cannot be changed after setup.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(selected == null
                  ? 'Select date of birth'
                  : MaterialLocalizations.of(context)
                      .formatMediumDate(selected!)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
            ),
          ],
        ),
      );
}

class _GenderStep extends StatelessWidget {
  const _GenderStep({
    required this.selected,
    required this.error,
    required this.onChoose,
    required this.onNext,
  });

  final String selected;
  final String? error;
  final ValueChanged<String> onChoose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _StepScaffold(
        icon: Icons.person_outline_rounded,
        title: 'How do you describe your gender?',
        subtitle: 'Choose an option. Gender cannot be changed after setup.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OnboardingChoices(
              selected: selected,
              values: _OnboardingFlowScreenState._genders,
              icon: Icons.person_outline_rounded,
              onChoose: onChoose,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
            ),
          ],
        ),
      );
}

class _OnboardingChoices extends StatelessWidget {
  const _OnboardingChoices({
    required this.selected,
    required this.values,
    required this.icon,
    required this.onChoose,
  });

  final String selected;
  final Map<String, String> values;
  final IconData icon;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: values.entries.map((entry) {
        final isSelected = selected == entry.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChoose(entry.key),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Icon(icon,
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value)),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: scheme.primary),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FitnessChoiceStep extends StatelessWidget {
  final bool? selected;
  final ValueChanged<bool> onChoose;
  const _FitnessChoiceStep({required this.selected, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.fitness_center_rounded,
      title: 'Would you also like to track your fitness?',
      subtitle:
          'Log workouts, meals, and body stats alongside your work — totally optional.',
      child: Column(
        children: [
          FilledButton(
            onPressed: () => onChoose(true),
            child: const Text('Yes, include Gym & Diet'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onChoose(false),
            child: const Text('No, just Work & Finance'),
          ),
        ],
      ),
    );
  }
}

class _NotificationsStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const _NotificationsStep({required this.onNext});

  @override
  ConsumerState<_NotificationsStep> createState() => _NotificationsStepState();
}

class _NotificationsStepState extends ConsumerState<_NotificationsStep> {
  bool _asking = false;

  Future<void> _allow() async {
    setState(() => _asking = true);
    try {
      await ref.read(notificationServiceProvider).requestPermissions();
    } finally {
      if (mounted) {
        setState(() => _asking = false);
        widget.onNext();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.notifications_active_rounded,
      title: 'Stay on top of reminders',
      subtitle:
          'Turn on notifications so WorkLog can alert you about reminders and, soon, overdue invoices.',
      child: Column(
        children: [
          FilledButton(
            onPressed: _asking ? null : _allow,
            child: _asking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.ivory))
                : const Text('Enable Notifications'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: widget.onNext, child: const Text('Not now')),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  final bool finishing;
  final VoidCallback onFinish;
  const _DoneStep({required this.finishing, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.check_circle_rounded,
      title: "You're all set",
      subtitle:
          'Your workspace is ready. Business details are optional and can be added later in Profile. You can change the fitness-tracking choice anytime.',
      child: FilledButton(
        onPressed: finishing ? null : onFinish,
        child: finishing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.ivory))
            : const Text('Go to Home'),
      ),
    );
  }
}
