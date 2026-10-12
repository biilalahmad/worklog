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
}
