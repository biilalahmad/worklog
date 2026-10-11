import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/app/app.dart';

void main() {
  testWidgets('scrolling has no Android stretch or glow indicator',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const WorkLogScrollBehavior(),
          home: ListView(
            children: List.generate(
              40,
              (index) => SizedBox(height: 64, child: Text('Row $index')),
            ),
          ),
        ),
      );

      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      await tester.fling(find.byType(ListView), const Offset(0, 600), 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
