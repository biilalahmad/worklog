import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import 'package:worklog/features/profile/domain/profile.dart';
import 'package:worklog/features/profile/presentation/providers/profile_providers.dart';

void main() {
  testWidgets(
      'all onboarding steps stay usable on a small phone with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            (ref) => Stream.value(
              const UserProfile(
                id: 'layout-test',
                displayName: 'Test User',
                defaultCurrency: 'PKR',
                gymEnabled: false,
                onboardingDone: false,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: const TextScaler.linear(1.15)),
              child: child!,
            );
          },
          home: const OnboardingFlowScreen(),
        ),
      ),
    );
    await _expectStepLayout(tester, 'What should we call you?', 1);

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Taylor');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await _expectStepLayout(tester, 'When were you born?', 2);

    await tester.ensureVisible(find.text('Select date of birth'));
    await tester.tap(find.text('Select date of birth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await _expectStepLayout(tester, 'How do you describe your gender?', 3);

    await tester.ensureVisible(find.text('Woman'));
    await tester.tap(find.text('Woman'));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await _expectStepLayout(
        tester, 'Would you also like to track your fitness?', 4);

    await tester.ensureVisible(find.text('No, just Work & Finance'));
    await tester.tap(find.text('No, just Work & Finance'));
    await _expectStepLayout(tester, 'Stay on top of reminders', 5);

    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await _expectStepLayout(tester, "You're all set", 6);
  });
}

Future<void> _expectStepLayout(
  WidgetTester tester,
  String heading,
  int step,
) async {
  await tester.pumpAndSettle();
  expect(find.text('Step $step of 6'), findsOneWidget);

  final scrollView = find.ancestor(
    of: find.text(heading),
    matching: find.byType(SingleChildScrollView),
  );
  expect(scrollView, findsOneWidget);
  final scrollable = find.descendant(
    of: scrollView,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  expect(scrollable, findsOneWidget);
  expect(find.byType(AnimatedContainer), findsNWidgets(6));
  expect(tester.takeException(), isNull);
}
