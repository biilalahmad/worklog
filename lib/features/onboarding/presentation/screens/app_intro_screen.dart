import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/first_launch_provider.dart';

class AppIntroScreen extends ConsumerStatefulWidget {
  const AppIntroScreen({super.key});

  @override
  ConsumerState<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _IntroPage {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  const _IntroPage(this.icon, this.eyebrow, this.title, this.body);
}

const _pages = [
  _IntroPage(
      Icons.work_outline_rounded,
      'YOUR WORKSPACE',
      'All your freelance work, together',
      'Keep clients, projects, invoices and work updates organized in one calm workspace.'),
  _IntroPage(
      Icons.insights_rounded,
      'STAY IN CONTROL',
      'Know what is done and what is due',
      'Track your time, income, expenses and reminders without losing sight of your next task.'),
  _IntroPage(
      Icons.fitness_center_rounded,
      'OPTIONAL WELLNESS',
      'Work first. Fitness if you want it.',
      'Gym, workouts and nutrition are optional. You can turn them on later and keep the rest of WorkLog simple.'),
];

class _AppIntroScreenState extends ConsumerState<AppIntroScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(firstLaunchPreferenceKey, true);
      ref.read(firstLaunchCompleteProvider.notifier).state = true;
      if (mounted) context.go('/login');
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.bolt_rounded,
                            color: scheme.onPrimary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text('WORKLOG',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(letterSpacing: 1.4)),
                      const Spacer(),
                      if (_index < _pages.length - 1)
                        TextButton(
                            onPressed: _finish, child: const Text('Skip')),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemBuilder: (context, index) {
                        final item = _pages[index];
                        return AnimatedBuilder(
                          animation: _controller,
                          child: _IntroContent(page: item),
                          builder: (context, child) {
                            final position = _controller.hasClients
                                ? (_controller.page ?? _index.toDouble()) -
                                    index
                                : 0.0;
                            final opacity =
                                (1 - position.abs() * .75).clamp(.2, 1.0);
                            return Opacity(
                              opacity: opacity,
                              child: Transform.translate(
                                  offset: Offset(position * -18, 0),
                                  child: child),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: i == _index ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            )),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _finishing ? null : _next,
                      child: _finishing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_index == _pages.length - 1
                              ? 'Get Started'
                              : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroContent extends StatelessWidget {
  const _IntroContent({required this.page});
  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: .75),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .7)),
              boxShadow: [
                BoxShadow(
                    color: scheme.primary.withValues(alpha: .10),
                    blurRadius: 32,
                    offset: const Offset(0, 12))
              ],
            ),
            child: Icon(page.icon, size: 68, color: scheme.primary),
          ),
          const SizedBox(height: 42),
          Text(page.eyebrow,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: scheme.primary, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text(page.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(page.body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45)),
        ],
      ),
    );
  }
}
