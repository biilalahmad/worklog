import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/core/widgets/client_picker_field.dart';
import 'package:worklog/features/clients/domain/client.dart';

void main() {
  testWidgets('selected client suggestions stay closed when focus returns',
      (tester) async {
    String? selectedId;
    const clients = [
      Client(id: '1', name: 'Ali'),
      Client(id: '2', name: 'Ahamd'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ClientPickerField(
          clients: clients,
          onChanged: (id) => selectedId = id,
        ),
      ),
    ));

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahamd').last);
    await tester.pumpAndSettle();
    expect(selectedId, '2');

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsNothing);
  });
}
