import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/check_email_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/assistant/domain/assistant_contract.dart';
import '../features/assistant/presentation/screens/assistant_screen.dart';
import '../features/gym/presentation/screens/body_stat_form_screen.dart';
import '../features/gym/presentation/screens/exercise_library_screen.dart';
import '../features/gym/presentation/screens/gym_dashboard_screen.dart';
import '../features/gym/presentation/screens/gym_sections_screen.dart';
import '../features/gym/presentation/screens/meal_form_screen.dart';
import '../features/gym/presentation/screens/routine_form_screen.dart';
import '../features/gym/presentation/screens/start_workout_screen.dart';
import '../features/gym/presentation/screens/workout_detail_screen.dart';
import '../features/gym/presentation/screens/workout_history_screen.dart';
import '../features/clients/domain/client.dart';
import '../features/clients/presentation/screens/client_detail_screen.dart';
import '../features/clients/presentation/screens/client_form_screen.dart';
import '../features/clients/presentation/screens/clients_screen.dart';
import '../features/clients/presentation/screens/project_form_screen.dart';
import '../features/finance/presentation/screens/analytics_screen.dart';
import '../features/finance/presentation/screens/financial_reports_screen.dart';
import '../features/finance/presentation/screens/expense_form_screen.dart';
import '../features/finance/presentation/screens/finance_screen.dart';
import '../features/finance/presentation/screens/income_form_screen.dart';
import '../features/finance/presentation/screens/pending_payments_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import '../features/onboarding/presentation/screens/app_intro_screen.dart';
import '../features/onboarding/presentation/screens/launching_screen.dart';
import '../features/onboarding/presentation/providers/first_launch_provider.dart';
import '../features/profile/presentation/providers/profile_providers.dart';
import '../features/profile/presentation/screens/change_password_screen.dart';
import '../features/profile/presentation/screens/delete_account_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/reminders/domain/reminder.dart';
import '../features/reminders/presentation/screens/reminder_form_screen.dart';
import '../features/reminders/presentation/screens/reminders_screen.dart';
import '../features/search/presentation/screens/search_screen.dart';
import '../features/work/domain/work_entry.dart';
import '../features/work/presentation/screens/video_stats_screen.dart';
import '../features/work/presentation/screens/work_form_screen.dart';
import '../features/work/presentation/screens/work_screen.dart';
import 'app_shell.dart';

const _authScreens = {'/login', '/signup', '/forgot-password', '/check-email'};

/// WorkLog supports real multi-user accounts, one-time onboarding, and
/// the password-recovery deep-link flow, so `redirect` below handles
/// four states in priority order: mid password-recovery, signed out,
/// signed in but not onboarded, and normal signed-in navigation.
/// `_GoRouterRefreshStream` bridges the auth stream (async) to
/// GoRouter's `refreshListenable` (sync re-evaluation on change); two
/// extra `ref.listen`s do the same for the recovery flag and the
/// profile stream (so onboarding completion redirects immediately).
final routerProvider = Provider<GoRouter>((ref) {
  final firstLaunchComplete = ref.watch(firstLaunchCompleteProvider);
  final refresh = _GoRouterRefreshStream(
      ref.watch(authRepositoryProvider).watchIsSignedIn());
  ref.onDispose(refresh.dispose);

  ref.listen<AsyncValue<AuthEvent>>(authEventsProvider, (previous, next) {
    if (next.valueOrNull == AuthEvent.passwordRecovery) {
      ref.read(passwordRecoveryProvider.notifier).state = true;
    }
    refresh.ping();
  });
  ref.listen(passwordRecoveryProvider, (previous, next) => refresh.ping());
  ref.listen(profileProvider, (previous, next) => refresh.ping());
  ref.listen(onboardingDoneProvider, (previous, next) => refresh.ping());

  return GoRouter(
    initialLocation: firstLaunchComplete ? '/login' : '/welcome',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final signedIn = ref.read(isSignedInProvider).valueOrNull ?? false;
      final inRecovery = ref.read(passwordRecoveryProvider);

      // A reset screen is public by design, but it can only mutate the
      // account when it receives a short-lived server-verified OTP ticket.
      if (loc == '/reset-password') return null;
      if (inRecovery) {
        return loc == '/reset-password' ? null : '/reset-password';
      }
      if (!signedIn) {
        if (!ref.read(firstLaunchCompleteProvider)) {
          return loc == '/welcome' ? null : '/welcome';
        }
        if (loc == '/welcome') return '/login';
        return _authScreens.contains(loc) ? null : '/login';
      }
      if (_authScreens.contains(loc)) return '/home';

      final profileState = ref.read(profileProvider);
      final onboardingState = ref.read(onboardingDoneProvider);
      // Onboarding completion is monotonic for a signed-in account. A cached
      // completed profile is enough to enter the saved workspace while the
      // live onboarding stream reconnects in the background.
      if (profileState.valueOrNull?.onboardingDone == true &&
          onboardingState.isLoading) {
        return loc == '/launching' ? '/home' : null;
      }
      if (profileState.hasError || onboardingState.hasError) {
        // If the server is unreachable but we have a cached signed-in profile,
        // let existing users continue instead of trapping them in onboarding.
        return profileState.valueOrNull == null
            ? (loc == '/launching' ? null : '/launching')
            : (loc == '/onboarding' ? '/home' : null);
      }
      if (profileState.isLoading || onboardingState.isLoading) {
        return loc == '/launching' ? null : '/launching';
      }

      // A missing profile must complete setup rather than bypass it;
      // loading and errors are handled by the explicit launching gate.
      final onboardingDone = onboardingState.valueOrNull ??
          profileState.valueOrNull?.onboardingDone ??
          false;
      if (!onboardingDone && loc != '/onboarding') return '/onboarding';
      if (onboardingDone && loc == '/onboarding') return '/home';
      if (loc == '/launching') return '/home';
      return null;
    },
    routes: [
      GoRoute(
          path: '/welcome',
          builder: (context, state) => const AppIntroScreen()),
      GoRoute(
          path: '/launching',
          builder: (context, state) => const LaunchingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/reset-password',
          builder: (context, state) => ResetPasswordScreen(
                ticket: state.extra is SecurityActionTicket
                    ? state.extra! as SecurityActionTicket
                    : null,
              )),
      GoRoute(
        path: '/check-email',
        builder: (context, state) =>
            CheckEmailScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingFlowScreen()),
      GoRoute(
          path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(
        path: '/assistant',
        builder: (context, state) {
          final matchingAgents = AssistantAgent.values.where(
            (agent) => agent.wireValue == state.uri.queryParameters['agent'],
          );
          return AssistantScreen(
            initialAgent: matchingAgents.isEmpty ? null : matchingAgents.first,
          );
        },
      ),
      GoRoute(
          path: '/profile/edit',
          builder: (context, state) => const EditProfileScreen()),
      GoRoute(
          path: '/profile/change-password',
          builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(
          path: '/profile/delete-account',
          builder: (context, state) => const DeleteAccountScreen()),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => const RemindersScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const ReminderFormScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) =>
                ReminderFormScreen(reminder: state.extra as Reminder?),
          ),
        ],
      ),
      GoRoute(
        path: '/gym/workout/start',
        builder: (context, state) => StartWorkoutScreen(
            routineId: state.uri.queryParameters['routineId']),
      ),
      GoRoute(
        path: '/gym/workout/:id',
        builder: (context, state) =>
            WorkoutDetailScreen(workoutId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: '/gym/history',
          builder: (context, state) => const WorkoutHistoryScreen()),
      GoRoute(
          path: '/gym/exercises',
          builder: (context, state) => const ExerciseLibraryScreen()),
      GoRoute(
          path: '/gym/sections',
          builder: (context, state) => GymSectionsScreen(
              initialIndex:
                  int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0)),
      GoRoute(
          path: '/gym/routines/new',
          builder: (context, state) => const RoutineFormScreen()),
      GoRoute(
        path: '/gym/routines/:id',
        builder: (context, state) =>
            RoutineFormScreen(routineId: state.pathParameters['id']),
      ),
      GoRoute(
          path: '/gym/body-stat/new',
          builder: (context, state) => const BodyStatFormScreen()),
      GoRoute(
          path: '/gym/meal/new',
          builder: (context, state) => const MealFormScreen()),
      GoRoute(
        path: '/work/new',
        builder: (context, state) => const WorkFormScreen(),
      ),
      GoRoute(
        path: '/work/video-stats',
        builder: (context, state) => const VideoStatsScreen(),
      ),
      GoRoute(
        path: '/work/:id/edit',
        builder: (context, state) =>
            WorkFormScreen(entry: state.extra as WorkEntry?),
      ),
      GoRoute(
        path: '/finance/income/new',
        builder: (context, state) => const IncomeFormScreen(),
      ),
      GoRoute(
        path: '/finance/expense/new',
        builder: (context, state) => const ExpenseFormScreen(),
      ),
      GoRoute(
        path: '/finance/pending',
        builder: (context, state) => const PendingPaymentsScreen(),
      ),
      GoRoute(
        path: '/finance/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/finance/reports',
        builder: (context, state) => const FinancialReportsScreen(),
      ),
      GoRoute(
        path: '/clients/new',
        builder: (context, state) => const ClientFormScreen(),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) =>
            ClientDetailScreen(clientId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                ClientFormScreen(client: state.extra as Client?),
          ),
          GoRoute(
            path: 'projects/new',
            builder: (context, state) =>
                ProjectFormScreen(clientId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: '/work', builder: (context, state) => const WorkScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
              path: '/home',
              pageBuilder: (context, state) =>
                  _fadeTab(state, const HomeScreen())),
          GoRoute(
              path: '/gym',
              pageBuilder: (context, state) =>
                  _fadeTab(state, const GymDashboardScreen())),
          GoRoute(
              path: '/finance',
              pageBuilder: (context, state) =>
                  _fadeTab(state, const FinanceScreen())),
          GoRoute(
              path: '/clients',
              pageBuilder: (context, state) =>
                  _fadeTab(state, const ClientsScreen())),
          GoRoute(
              path: '/profile',
              pageBuilder: (context, state) =>
                  _fadeTab(state, const ProfileScreen())),
        ],
      ),
    ],
  );
});

/// A quick, short fade+scale used only for switching between the
/// bottom-nav tabs — noticeably faster than a full page-push transition
/// so tab switching still feels snappy, not sluggish.
CustomTransitionPage<void> _fadeTab(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.985, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Converts a Stream (here, auth-state changes) into a Listenable so
/// GoRouter's `refreshListenable` re-runs `redirect` the moment sign-in
/// state changes — without this, a fresh login wouldn't kick the user
/// off the login screen until some unrelated navigation happened.
class _GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  /// Public trigger for the extra (non-stream) redirect conditions —
  /// password-recovery flag and profile changes — set up above via
  /// `ref.listen`, since `notifyListeners()` itself is protected.
  void ping() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
