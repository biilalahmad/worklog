import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/responsive.dart';
import '../features/profile/presentation/providers/profile_providers.dart';
import 'theme/app_tokens.dart';

class _TabItem {
  final String? path;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  const _TabItem({
    this.path,
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

const _home = _TabItem(
    path: '/home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home');
const _gym = _TabItem(
    path: '/gym',
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center_rounded,
    label: 'Gym');
const _finance = _TabItem(
    path: '/finance',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    label: 'Finance');
const _clients = _TabItem(
    path: '/clients',
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt_rounded,
    label: 'Clients');
const _profile = _TabItem(
    path: '/profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'Profile');
List<_TabItem> _tabsFor({required bool gymEnabled}) {
  return gymEnabled
      ? [_home, _clients, _finance, _gym, _profile]
      : [_home, _clients, _finance, _profile];
}

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  int _currentIndex(BuildContext context, List<_TabItem> tabs) {
    final location = GoRouterState.of(context).uri.toString();
    return tabs
        .indexWhere((t) => t.path != null && location.startsWith(t.path!));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymEnabled = ref.watch(gymEnabledProvider);
    final tabs = _tabsFor(gymEnabled: gymEnabled);
    final currentIndex = _currentIndex(context, tabs);

    if (context.useSideNavigation) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex == -1 ? null : currentIndex,
              onDestinationSelected: (index) =>
                  navigationShell.goBranch(_branchIndex(tabs[index])),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                          color: AppColors.forest, shape: BoxShape.circle),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/worklog_icon.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              destinations: [
                for (final tab in tabs)
                  NavigationRailDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: Text(tab.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: navigationShell,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        tabs: tabs,
        currentIndex: currentIndex,
        onTap: (index) => navigationShell.goBranch(_branchIndex(tabs[index])),
      ),
    );
  }

  int _branchIndex(_TabItem tab) => switch (tab.path) {
        '/home' => 0,
        '/clients' => 1,
        '/finance' => 2,
        '/gym' => 3,
        '/profile' => 4,
        _ => 0,
      };
}

/// A responsive frosted-glass navigation pill. Each destination keeps
/// its label visible so the 4/5-item layout stays easy to scan.
class _FloatingNavBar extends StatelessWidget {
  final List<_TabItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      // Keep the recent, subtle raised position while restoring the prior
      // four/five destination bar design and sizing.
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, bottomInset > 0 ? bottomInset + 12 : 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: AppColors.forest.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: AppSpacing.navBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.surface.withValues(alpha: 0.88)
                  : AppColors.navBar,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: (isDark ? scheme.outlineVariant : Colors.white)
                      .withValues(alpha: 0.78)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                      child: _NavBarItem(
                          tab: tabs[i],
                          selected: i == currentIndex,
                          onTap: () => onTap(i)))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final _TabItem tab;
  final bool selected;
  final VoidCallback onTap;
  const _NavBarItem(
      {required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 76;
        final scheme = Theme.of(context).colorScheme;
        final label = Text(
          tab.label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 9.5 : 10.5,
            height: 1.1,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
        );
        final labelWidth = TextPainter(
          text: TextSpan(text: tab.label, style: label.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final desiredPillWidth =
            labelWidth.width + 2 * AppSpacing.navPillHorizontal;
        final maxPillWidth = math.max(0.0, constraints.maxWidth - 8);
        final pillWidth = math.min(desiredPillWidth, maxPillWidth);

        return Semantics(
          button: true,
          selected: selected,
          label: tab.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: selected ? pillWidth : null,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: ShapeDecoration(
                  color: selected
                      ? (scheme.brightness == Brightness.dark
                          ? scheme.primaryContainer.withValues(alpha: 0.86)
                          : AppColors.limeSoft.withValues(alpha: 0.86))
                      : Colors.transparent,
                  shape: const StadiumBorder(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NavIcon(tab: tab, selected: selected),
                    const SizedBox(height: 3),
                    label,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavIcon extends StatelessWidget {
  final _TabItem tab;
  final bool selected;
  const _NavIcon({required this.tab, required this.selected});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (widget, anim) =>
            ScaleTransition(scale: anim, child: widget),
        child: Icon(
          selected ? tab.selectedIcon : tab.icon,
          key: ValueKey(selected),
          size: 22,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}
