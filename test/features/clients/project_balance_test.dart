import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/clients/domain/project.dart';

void main() {
  test('clamps a historical overpayment to zero amount remaining', () {
    final project = Project.fromMap({
      'id': 'project-1',
      'client_id': 'client-1',
      'title': 'Editing',
      'total_amount': 10000,
      'amount_paid': 20000,
      'amount_remaining': -10000,
      'currency': 'EUR',
      'status': 'paid',
    });

    expect(project.amountRemainingMinor, 0);
  });

  test('uses the backend outstanding balance when it is present', () {
    final project = Project.fromMap({
      'id': 'project-2',
      'client_id': 'client-1',
      'title': 'Editing',
      'total_amount': 10000,
      'amount_paid': 6000,
      'amount_remaining': 3200,
      'currency': 'PKR',
      'status': 'partiallyPaid',
    });

    expect(project.amountRemainingMinor, 3200);
  });

  test('falls back to total less paid for older cached records', () {
    final project = Project.fromMap({
      'id': 'project-3',
      'client_id': 'client-1',
      'title': 'Editing',
      'total_amount': 10000,
      'amount_paid': 6000,
      'currency': 'PKR',
      'status': 'partiallyPaid',
    });

    expect(project.amountRemainingMinor, 4000);
  });
}
