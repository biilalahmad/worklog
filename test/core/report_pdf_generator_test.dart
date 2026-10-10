import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/core/pdf/report_pdf_generator.dart';
import 'package:worklog/features/finance/domain/expense.dart';
import 'package:worklog/features/finance/domain/income.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds branded monthly financial report variants', () async {
    final currencies = ['USD', 'EUR', 'GBP', 'PKR', 'TRY'];
    final income = List.generate(
      12,
      (index) => Income(
        id: 'in-$index',
        clientId: 'client-1',
        amountMinor: 123456,
        currency: currencies[index % currencies.length],
        date: DateTime(2026, 10, 10 - index),
        method: 'Bank transfer',
        description: index == 0
            ? 'Home now shows work entries, completed tasks, hours, and income instead of video-based metrics. “Video Stats” is now “Work Stats,” with summaries by period, work type, and client. — Includes 100.00 tip'
            : null,
      ),
    );
    final expenses = [
      Expense(
        id: 'out-1',
        amountMinor: 2500,
        currency: 'EUR',
        date: DateTime(2026, 10, 9),
        category: 'Software',
        description: 'Design subscription',
      ),
    ];

    for (final kind in ReportKind.values) {
      final bytes = await ReportPdfGenerator.buildPdf(
        month: DateTime(2026, 10),
        kind: kind,
        income: income,
        expenses: expenses,
        userName: 'Bilal Ahmed',
        issuedAt: DateTime(2026, 10, 10, 17, 46),
      );
      expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-'));
      expect(bytes.length, greaterThan(1000));
      if (Platform.environment['WORKLOG_RENDER_REPORT'] == '1' &&
          kind == ReportKind.combined) {
        final preview = File(
            '${Directory.systemTemp.path}${Platform.pathSeparator}worklog-report-preview.pdf');
        await preview.writeAsBytes(bytes, flush: true);
      }
    }
  });
}
