import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/core/widgets/app_select_field.dart';

void main() {
  testWidgets('an unselected picker keeps its hint separate from the label',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppSelectField<String>(
          label: 'Project (optional)',
          value: null,
          hintText: 'No project selected',
          options: const [AppSelectOption(value: 'p1', label: 'Project One')],
          onChanged: (_) {},
        ),
      ),
    ));

    expect(find.text('Project (optional)'), findsOneWidget);
    expect(find.text('No project selected'), findsOneWidget);
  });

  testWidgets('a picker selection applies once and closes the menu',
      (tester) async {
    var value = 'PKR';
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Center(
            child: AppSelectField<String>(
              label: 'Currency',
              value: value,
              options: const [
                AppSelectOption(value: 'PKR', label: 'PKR'),
                AppSelectOption(value: 'USD', label: 'USD'),
              ],
              onChanged: (next) => setState(() => value = next ?? value),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(AppSelectField<String>));
    await tester.pumpAndSettle();
    expect(find.text('USD'), findsOneWidget);

    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();

    expect(value, 'USD');
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('PKR'), findsNothing);
  });
}
