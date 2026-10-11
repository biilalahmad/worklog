import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/date_keys.dart';
import '../../../../core/utils/local_day_provider.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/refresh_with_network.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/money_display.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../../work/domain/work_entry.dart';
import '../../../work/presentation/providers/work_providers.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../providers/home_providers.dart';
import '../providers/startup_tasks_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _now;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(startupTasksProvider); // fire-and-forget, once per session
    ref.watch(localCalendarDayProvider);
    final now = _now;
    final dayPhase = _DayPhase.from(now);
    final todayRange =
        DateRange(DateKeys.startOfDay(now), DateKeys.endOfDay(now));
    final scheme = Theme.of(context).colorScheme;

    final todayWorkAsync = ref.watch(workEntriesForRangeProvider(todayRange));
    final todayIncomeAsync = ref.watch(incomeForRangeProvider(todayRange));
    final monthStatsAsync = ref.watch(monthStatsProvider(DateKeys.month(now)));
    final remindersAsync = ref.watch(upcomingRemindersProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final email = ref.watch(authRepositoryProvider).currentUserEmail;
    final profileName = profile?.displayName.trim();
    final nameIsGeneric = profileName == null ||
        profileName.isEmpty ||
        profileName == 'WorkLog User';
    final firstName = nameIsGeneric
        ? AvatarCircle.firstNameFromEmail(email)
        : profileName.split(RegExp(r'\s+')).first;
    final greetingWord = switch (now.hour) {
      < 5 => 'Good night',
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      < 21 => 'Good evening',
      _ => 'Good night',
    };

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: _TopGlassGlow(phase: dayPhase),
        titleSpacing: 4,
        leadingWidth: 62,
        leading: Center(
          child: AvatarCircle(
            imageUrl: profile?.avatarUrl,
            initials: profile?.avatarUrl?.isNotEmpty == true
                ? profile!.initials
                : (AvatarCircle.initialsFromEmail(email) ??
                    profile?.initials ??
                    '?'),
            seed: email ?? profile?.displayName,
            size: 42,
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greetingWord,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            Text(firstName ?? 'Your workspace',
                style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/reminders')),
          IconButton(
              tooltip: 'Ask WorkLog',
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () => context.push('/assistant')),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => refreshWithNetworkMessage(context, () async {
          // Reconnect the live streams, but don't keep the pull-to-refresh
          // indicator open until every network query has returned.
          ref.invalidate(workEntriesForRangeProvider(todayRange));
          ref.invalidate(incomeForRangeProvider(todayRange));
          ref.invalidate(monthStatsProvider(DateKeys.month(now)));
          ref.invalidate(upcomingRemindersProvider);
          ref.invalidate(clientsListProvider);
        }),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            96 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Row(
              children: [
                _GlassIconTile(
                  width: 42,
                  height: 42,
                  phase: dayPhase,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(now),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        dayPhase.message,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Consumer(builder: (context, ref, _) {
              final clients = ref.watch(clientsListProvider).valueOrNull;
              if (clients == null || clients.isNotEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SectionCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.rocket_launch_outlined,
                          color: scheme.primary, size: 28),
                      const SizedBox(height: 10),
                      Text('Add your first client to get started',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                          'Once you add a client you can log work, track income, and send invoices.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => context.push('/clients/new'),
                        icon: const Icon(Icons.person_add_alt_rounded),
                        label: const Text('Add Client'),
                      ),
                    ],
                  ),
                ),
              );
            }),
            FadeSlideIn(
              child: _HeroCard(
                  monthStatsAsync: monthStatsAsync,
                  todayIncomeAsync: todayIncomeAsync,
                  phase: dayPhase),
            ),
            const SizedBox(height: 20),
            const _HomeQuickActions(),
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossCount = width >= 720 ? 4 : 2;
                  const tileHeight = 120.0;
                  final tileWidth =
                      (width - (12 * (crossCount - 1))) / crossCount;
                  return GridView.count(
                    crossAxisCount: crossCount,
                    shrinkWrap: true,
                    // Nested scrollables otherwise inherit the system safe
                    // padding and leave a large blank strip after the grid.
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: tileWidth / tileHeight,
                    children: [
                      todayWorkAsync.when(
                        loading: () => const _StatTile(
                            label: 'Work entries today', value: '···'),
                        error: (e, _) => const _StatTile(
                            label: 'Work entries today',
                            value: '—',
                            error: true),
                        data: (entries) => _StatTile(
                          label: 'Work entries today',
                          value: '${entries.length}',
                          icon: Icons.work_outline_rounded,
                        ),
                      ),
                      todayWorkAsync.when(
                        loading: () => const _StatTile(
                            label: 'Work Delivered today', value: '···'),
                        error: (e, _) => const _StatTile(
                            label: 'Work Delivered today',
                            value: '—',
                            error: true),
                        data: (entries) => _StatTile(
                          label: 'Work Delivered today',
                          value:
                              '${entries.where((e) => e.status == WorkStatus.completed || e.status == WorkStatus.delivered).length}',
                          icon: Icons.task_alt_rounded,
                        ),
                      ),
                      todayWorkAsync.when(
                        loading: () => const _StatTile(
                            label: 'Hours worked', value: '···'),
                        error: (e, _) => const _StatTile(
                            label: 'Hours worked', value: '—', error: true),
                        data: (entries) => _StatTile(
                          label: 'Hours worked',
                          value: entries
                              .fold<double>(0, (s, e) => s + e.hoursWorked)
                              .toStringAsFixed(1),
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                      ref.watch(clientsListProvider).when(
                            loading: () => const _StatTile(
                                label: 'Clients added today', value: '···'),
                            error: (e, _) => const _StatTile(
                                label: 'Clients added today',
                                value: '—',
                                error: true),
                            data: (clients) => _StatTile(
                              label: 'Clients added today',
                              value:
                                  '${clients.where((client) => client.createdAt != null && DateUtils.isSameDay(client.createdAt!.toLocal(), now)).length}',
                              icon: Icons.person_add_alt_1_outlined,
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: SectionCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.push('/work'),
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.work_outline_rounded,
                        color: scheme.primary, size: 18),
                  ),
                  title: const Text('Work Log',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('View and add work entries'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming Reminders',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  remindersAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(Failure.from(e).message,
                          style: TextStyle(color: scheme.error)),
                    ),
                    data: (reminders) {
                      // Show the nearest few reminders that haven't happened
                      // yet — not just ones landing on an exact date, so a
                      // reminder several days out still shows up here
                      // instead of the section looking empty.
                      final upcoming = reminders
                          .where((r) => r.dateTime.isAfter(now))
                          .toList()
                        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                      if (upcoming.isEmpty) {
                        return SectionCard(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            height: 142,
                            width: double.infinity,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_none_rounded,
                                      size: 28, color: scheme.primary),
                                  const SizedBox(height: 8),
                                  Text('No upcoming reminders',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  const SizedBox(height: 4),
                                  Text('Add a reminder to stay on track.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                      return SectionCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Column(
                          children: upcoming
                              .take(3)
                              .map((r) => ListTile(
                                    leading: const Icon(
                                        Icons.notifications_outlined),
                                    title: Text(r.title),
                                    subtitle: Text(
                                      '${_dayLabel(r.dateTime, now)} · ${DateFormat('h:mm a').format(r.dateTime)}',
                                    ),
                                    trailing:
                                        r.description?.trim().isNotEmpty == true
                                            ? IconButton(
                                                tooltip:
                                                    'Open reminder description',
                                                onPressed: () =>
                                                    _showReminderDescription(
                                                        context,
                                                        r.title,
                                                        r.description!),
                                                icon: const Icon(
                                                    Icons.notes_outlined),
                                              )
                                            : null,
                                  ))
                              .toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showReminderDescription(
    BuildContext context, String title, String description) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined),
      title: Text(title),
      content: SingleChildScrollView(child: Text(description.trim())),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    ),
  );
}

enum _DayPhase {
  morning,
  afternoon,
  evening,
  night;

  static _DayPhase from(DateTime time) {
    if (time.hour >= 5 && time.hour < 12) return _DayPhase.morning;
    if (time.hour < 17) return _DayPhase.afternoon;
    if (time.hour < 21) return _DayPhase.evening;
    return _DayPhase.night;
  }
}

extension on _DayPhase {
  IconData get icon => switch (this) {
        _DayPhase.morning => Icons.wb_sunny_outlined,
        _DayPhase.afternoon => Icons.light_mode_outlined,
        _DayPhase.evening => Icons.wb_twilight_outlined,
        _DayPhase.night => Icons.nights_stay_outlined,
      };

  String get message => switch (this) {
        _DayPhase.morning => 'A fresh start for your business',
        _DayPhase.afternoon => 'Keep your momentum going',
        _DayPhase.evening => 'Wrap up your day with clarity',
        _DayPhase.night => 'Plan tomorrow at your own pace',
      };

  Color colorFor(bool dark) => dark ? AppColors.lime : AppColors.forestLight;
}

class _TopGlassGlow extends StatelessWidget {
  final _DayPhase phase;
  const _TopGlassGlow({required this.phase});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = phase.colorFor(isDark);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glow.withValues(alpha: isDark ? 0.16 : 0.12),
            Colors.transparent
          ],
        ),
        border: Border(
            bottom: BorderSide(
                color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.32))),
      ),
    );
  }
}

class _GlassIconTile extends StatelessWidget {
  final double width;
  final double height;
  final _DayPhase phase;
  const _GlassIconTile(
      {required this.width, required this.height, required this.phase});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = phase.colorFor(isDark);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: glow.withValues(alpha: isDark ? 0.24 : 0.17),
            border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.58)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(phase.icon,
              color: isDark ? glow : Theme.of(context).colorScheme.primary,
              size: 21),
        ),
      ),
    );
  }
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actions = [
      (Icons.work_outline_rounded, 'Work', '/work/new'),
      (Icons.add_card_rounded, 'Income', '/finance/income/new'),
      (Icons.remove_circle_outline_rounded, 'Expense', '/finance/expense/new'),
      (Icons.person_add_alt_rounded, 'Client', '/clients/new'),
      (Icons.notifications_active_outlined, 'Reminder', '/reminders/new'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final action in actions)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.push(action.$3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? scheme.surfaceContainerHigh
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isDark
                                        ? scheme.outlineVariant
                                            .withValues(alpha: 0.55)
                                        : AppColors.forest
                                            .withValues(alpha: 0.12)),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.forest.withValues(
                                        alpha: isDark ? 0.07 : 0.11),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(action.$1,
                                  color: scheme.primary, size: 22),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              action.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final AsyncValue monthStatsAsync;
  final AsyncValue todayIncomeAsync;
  final _DayPhase phase;
  const _HeroCard(
      {required this.monthStatsAsync,
      required this.todayIncomeAsync,
      required this.phase});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthIncome = monthStatsAsync.maybeWhen<MoneyByCurrency?>(
      data: (s) => s.income,
      orElse: () => null,
    );
    final hours = monthStatsAsync.maybeWhen(
        data: (s) => s.hoursWorked.toStringAsFixed(1), orElse: () => '···');
    final tasks = monthStatsAsync.maybeWhen(
        data: (s) => '${s.tasksCompleted}', orElse: () => '···');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = phase.colorFor(isDark);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      glow.withValues(alpha: 0.22),
                      scheme.surface.withValues(alpha: 0.30)
                    ]
                  : [AppColors.forest, AppColors.forestLight],
            ),
            border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.26)),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: (isDark ? glow : AppColors.forest)
                      .withValues(alpha: isDark ? 0.20 : 0.28),
                  blurRadius: 30,
                  offset: const Offset(0, 14))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle),
                    child: Icon(Icons.insights_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('MONTHLY OVERVIEW',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      )),
                ],
              ),
              const SizedBox(height: 18),
              Text('This month\'s earnings',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14)),
              const SizedBox(height: 6),
              if (monthIncome == null)
                const Text('···',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700))
              else
                MoneyTotalsDisplay(
                  monthIncome,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                      child: _HeroStat(label: 'Hours worked', value: hours)),
                  Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withValues(alpha: 0.25)),
                  Expanded(child: _HeroStat(label: 'Tasks done', value: tasks)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool error;
  const _StatTile(
      {required this.label,
      required this.value,
      this.icon,
      this.error = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: error ? scheme.error : scheme.primary),
          if (icon != null) const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: error ? scheme.error : null,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// "Today" / "Tomorrow" / a short date — matches how most reminder and
/// calendar apps label near-future dates, in English (reminder/
/// notification-facing text is kept in English throughout the app).
String _dayLabel(DateTime dateTime, DateTime now) {
  final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1 && diff < 7) return DateFormat('EEEE').format(dateTime);
  return DateFormat('MMM d').format(dateTime);
}
