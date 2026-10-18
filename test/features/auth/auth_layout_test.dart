import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/app/theme/app_theme.dart';
import 'package:worklog/core/errors/failure.dart';
import 'package:worklog/features/auth/domain/auth_repository.dart';
import 'package:worklog/features/auth/presentation/providers/auth_providers.dart';
import 'package:worklog/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:worklog/features/auth/presentation/screens/login_screen.dart';
import 'package:worklog/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:worklog/features/auth/presentation/screens/signup_screen.dart';

void main() {
  test('light and dark app themes use the bundled Poppins family', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Poppins');
      expect(theme.textTheme.headlineMedium?.fontFamily, 'Poppins');
    }
  });

  testWidgets('signup shows a login hint when the email already has an account',
      (tester) async {
    final repository = _FakeAuthRepository(
      signUpResult: const SignUpResult(
        needsVerification: false,
        alreadyRegistered: true,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SignupScreen()),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(2), 'StrongPass123');
    await tester.enterText(fields.at(3), 'StrongPass123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(
      find.text(Failure.accountAlreadyExists),
      findsOneWidget,
    );
    expect(find.text('Check your email'), findsNothing);
  });

  testWidgets('compact authentication forms fit a small phone viewport',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _expectNoScroll(tester, const SignupScreen(), scale: 1);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.textSpan?.toPlainText().contains('Terms of Service') ??
                false),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.textSpan?.toPlainText().contains('Privacy Policy') ??
                false),
      ),
      findsOneWidget,
    );
    await _expectNoScroll(tester, const LoginScreen(), scale: 1);
    await _expectNoScroll(tester, const ForgotPasswordScreen(), scale: 1.15);
    await _expectNoScroll(
      tester,
      const ResetPasswordScreen(
        ticket: SecurityActionTicket(email: 'user@example.com', value: 'test'),
      ),
      scale: 1.15,
    );
  });
}

Future<void> _expectNoScroll(
  WidgetTester tester,
  Widget screen, {
  required double scale,
  bool allowScroll = false,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: MaterialApp(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();

  final pageScroll = find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(Scrollable),
  );
  expect(find.byType(SingleChildScrollView), findsOneWidget);
  final scrollExtent =
      tester.state<ScrollableState>(pageScroll.first).position.maxScrollExtent;
  if (screen is SignupScreen || screen is ForgotPasswordScreen) {
    final formCenter = tester.getRect(find.byType(Form)).center.dy;
    final contentCenter =
        tester.getRect(find.byType(SingleChildScrollView)).center.dy;
    expect((formCenter - contentCenter).abs(), lessThan(20));
  }
  if (allowScroll) {
    expect(scrollExtent, greaterThanOrEqualTo(0));
  } else {
    expect(scrollExtent, 0);
  }
  expect(tester.takeException(), isNull,
      reason: '${screen.runtimeType} layout');
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.signUpResult = const SignUpResult(needsVerification: true),
  });

  final SignUpResult signUpResult;

  @override
  bool get isSignedIn => false;

  @override
  String? get currentUserEmail => null;

  @override
  String? get currentUserId => null;

  @override
  Stream<AuthEvent> watchAuthEvents() => const Stream.empty();

  @override
  Stream<bool> watchIsSignedIn() => const Stream.empty();

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      signUpResult;

  @override
  Future<void> signIn(
      {required String email, required String password}) async {}

  @override
  Future<bool> signInWithGoogle() async => false;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resendVerification(String email) async {}

  @override
  Future<void> requestSecurityCode(
      {required String action, String? email}) async {}

  @override
  Future<SecurityActionTicket> verifySecurityCode({
    required String action,
    required String code,
    String? email,
  }) async =>
      SecurityActionTicket(email: email ?? '', value: 'ticket');

  @override
  Future<void> completeVerifiedAction({
    required String action,
    required String email,
    required String ticket,
    String? newPassword,
    String? currentPassword,
  }) async {}
}
