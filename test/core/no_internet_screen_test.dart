import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/core/widgets/no_internet_screen.dart';

void main() {
  testWidgets('shows retry and reports taps', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NoInternetScreen(onRetry: () => retries++),
      ),
    );

    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('retry shows progress and disables repeated taps',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoInternetScreen(onRetry: null, isRetrying: true),
      ),
    );

    expect(find.text('Checking connection…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits a phone screen in $brightness theme', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF183B62),
            brightness: brightness,
          )),
          home: NoInternetScreen(onRetry: () {}),
        ),
      );

      expect(find.text('No internet connection'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
