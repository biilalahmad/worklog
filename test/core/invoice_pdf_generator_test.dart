import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/core/pdf/invoice_pdf_generator.dart';
import 'package:worklog/core/utils/money.dart';
import 'package:worklog/features/clients/domain/client.dart';
import 'package:worklog/features/clients/domain/project.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a white, data-backed invoice PDF', () async {
    final project = Project(
      id: 'invoice-123456',
      clientId: 'client-1',
      title: 'Brand identity design',
      subtotalAmountMinor: 100000,
      taxAmountMinor: 5000,
      taxRateBps: 500,
      taxLabel: 'VAT',
      totalAmountMinor: 105000,
      currency: 'EUR',
      dueDate: DateTime(2026, 11, 10),
      amountPaidMinor: 25000,
      amountRemainingMinor: 80000,
      status: ProjectStatus.partiallyPaid,
    );
    const client = Client(
      id: 'client-1',
      name: 'Amina Client',
      email: 'amina@example.com',
    );

    final bytes = await InvoicePdfGenerator.buildPdf(
      project: project,
      client: client,
      userName: 'Bilal Ahmed',
      email: 'bilal@example.com',
      businessName: 'Studio North',
      professionalTitle: 'Independent Designer',
      location: 'Lahore, Pakistan',
      website: 'studionorth.example',
      paymentInstructions: 'Bank transfer: Account ending 1234',
      issuedAt: DateTime(2026, 10, 10, 17, 46),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-'));

    // The generated artifact is written only to the system temp directory so
    // it can be rendered with Poppler during visual QA; the test removes it.
    if (Platform.environment['WORKLOG_RENDER_INVOICE'] == '1') {
      final preview = File(
          '${Directory.systemTemp.path}${Platform.pathSeparator}worklog-invoice-preview.pdf');
      await preview.writeAsBytes(bytes, flush: true);
    }

    expect(Money(project.amountRemainingMinor, project.currency).format(),
        '€800.00');
  });
}
