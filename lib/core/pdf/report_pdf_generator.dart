import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/finance/domain/expense.dart';
import '../../features/finance/domain/income.dart';
import '../utils/money.dart';

enum ReportKind { income, spending, combined }

/// Builds a monthly financial report PDF from real income/expense
/// records already loaded for that month — no simulated data.
class ReportPdfGenerator {
  static Future<void> generateAndShare({
    required DateTime month,
    required ReportKind kind,
    required List<Income> income,
    required List<Expense> expenses,
    required String userName,
  }) async {
    final bytes = await buildPdf(
      month: month,
      kind: kind,
      income: income,
      expenses: expenses,
      userName: userName,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'Financial_Report_${DateFormat('yyyy_MM').format(month)}_${kind.name}.pdf',
    );
  }

  static Future<Uint8List> buildPdf({
    required DateTime month,
    required ReportKind kind,
    required List<Income> income,
    required List<Expense> expenses,
    required String userName,
    DateTime? issuedAt,
  }) async {
    final doc = pw.Document();
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final generatedAt = issuedAt ?? DateTime.now();
    const accent = PdfColor.fromInt(0xFF1E3A5F);
    const sky = PdfColor.fromInt(0xFF5DB2F0);
    const ink = PdfColor.fromInt(0xFF1B2A41);
    const muted = PdfColor.fromInt(0xFF5F7189);
    const line = PdfColor.fromInt(0xFFDCE5EF);
    const softBlue = PdfColor.fromInt(0xFFF1F6FB);
    final logoBytes = (await rootBundle.load('assets/images/worklog_icon.png'))
        .buffer
        .asUint8List();
    final logo = pw.MemoryImage(Uint8List.fromList(logoBytes));
    final issuedLabel =
        DateFormat('MMM d, yyyy \'at\' h:mm a').format(generatedAt);

    final totalIncome = _sumByCurrency(
        income.map((item) => Money(item.amountMinor.abs(), item.currency)));
    final totalExpenses = _sumByCurrency(
        expenses.map((item) => Money(item.amountMinor.abs(), item.currency)));
    final net = <String, int>{...totalIncome.toMap()};
    for (final entry in totalExpenses.toMap().entries) {
      net[entry.key] = (net[entry.key] ?? 0) - entry.value;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 38, 42, 42),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        header: (context) => context.pageNumber > 1
            ? pw.Column(children: [
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(children: [
                        pw.Image(logo, width: 20, height: 20),
                        pw.SizedBox(width: 6),
                        pw.Text('WorkLog',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: accent)),
                      ]),
                      pw.Text('$monthLabel  |  ${_kindLabel(kind)}',
                          style: const pw.TextStyle(fontSize: 9, color: muted)),
                    ]),
                pw.SizedBox(height: 8),
                pw.Divider(color: line),
              ])
            : pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(height: 5, color: sky),
                  pw.SizedBox(height: 18),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(children: [
                          pw.Image(logo, width: 30, height: 30),
                          pw.SizedBox(width: 8),
                          pw.Text('WorkLog',
                              style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accent)),
                        ]),
                        pw.Text('FINANCIAL REPORT',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: muted)),
                      ]),
                  pw.SizedBox(height: 15),
                  pw.Text(monthLabel,
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: ink)),
                  pw.SizedBox(height: 4),
                  pw.Text('${_kindLabel(kind)}  |  Prepared for $userName',
                      style: const pw.TextStyle(fontSize: 10, color: muted)),
                  pw.Text('Issued $issuedLabel',
                      style: const pw.TextStyle(fontSize: 9, color: muted)),
                  pw.SizedBox(height: 12),
                  pw.Divider(color: line),
                ],
              ),
        footer: (context) => pw.Text(
          'WorkLog  |  Issued $issuedLabel  |  Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: muted),
        ),
        build: (context) => [
          if (kind == ReportKind.income || kind == ReportKind.combined) ...[
            _summaryCard('Income received', _formatTotals(totalIncome), sky,
                softBlue, ink),
            pw.SizedBox(height: 16),
            pw.Text('Income',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: accent)),
            pw.SizedBox(height: 6),
            _incomeEntries(income),
            pw.SizedBox(height: 20),
          ],
          if (kind == ReportKind.spending || kind == ReportKind.combined) ...[
            _summaryCard('Spending recorded', _formatTotals(totalExpenses), sky,
                softBlue, ink),
            pw.SizedBox(height: 16),
            pw.Text('Spending',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: accent)),
            pw.SizedBox(height: 6),
            _transactionTable(
              rows: expenses
                  .map((e) => [
                        DateFormat('MMM d').format(e.date),
                        e.category,
                        e.description?.trim().isNotEmpty == true
                            ? e.description!.trim()
                            : '-',
                        _formatMoney(e.amountMinor.abs(), e.currency),
                      ])
                  .toList(),
              headers: const ['Date', 'Category', 'Description', 'Amount'],
            ),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total Spending: ${_formatTotals(totalExpenses)}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: accent)),
            ),
          ],
          if (kind == ReportKind.combined) ...[
            pw.SizedBox(height: 16),
            _summaryCard('Net by currency', _formatTotals(MoneyByCurrency(net)),
                sky, softBlue, ink),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static MoneyByCurrency _sumByCurrency(Iterable<Money> amounts) {
    final totals = <String, int>{};
    for (final amount in amounts) {
      totals[amount.currency] =
          (totals[amount.currency] ?? 0) + amount.minorUnits;
    }
    return MoneyByCurrency(totals);
  }

  static pw.Widget _transactionTable(
      {required List<List<String>> rows, required List<String> headers}) {
    if (rows.isEmpty) {
      return pw.Text('No records for this period.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500));
    }
    return pw.Table.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A5F)),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellHeight: 22,
      cellAlignments: {0: pw.Alignment.centerLeft, 3: pw.Alignment.centerRight},
    );
  }

  static pw.Widget _incomeEntries(List<Income> income) {
    if (income.isEmpty) {
      return pw.Text('No records for this period.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500));
    }
    return pw.Column(
      children: [
        for (final item in income) ...[
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFDCE5EF))),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          child: pw.Text(
                        _pdfSafeText(item.method.trim().isEmpty
                            ? 'Income'
                            : item.method),
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF1B2A41)),
                      )),
                      pw.SizedBox(width: 12),
                      pw.Text(
                          _formatMoney(item.amountMinor.abs(), item.currency),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF1E3A5F))),
                    ]),
                pw.SizedBox(height: 3),
                pw.Text(DateFormat('MMM d, yyyy').format(item.date),
                    style: const pw.TextStyle(
                        fontSize: 8.5, color: PdfColor.fromInt(0xFF5F7189))),
                if (item.description?.trim().isNotEmpty == true) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(_pdfSafeText(item.description!.trim()),
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColor.fromInt(0xFF1B2A41))),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _kindLabel(ReportKind kind) {
    switch (kind) {
      case ReportKind.income:
        return 'Monthly Income';
      case ReportKind.spending:
        return 'Monthly Spending';
      case ReportKind.combined:
        return 'Income + Spending';
    }
  }

  static pw.Widget _summaryCard(String label, String value, PdfColor accent,
          PdfColor background, PdfColor ink) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 3, height: 30, color: accent),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(label, style: pw.TextStyle(fontSize: 9, color: ink)),
                  pw.SizedBox(height: 4),
                  pw.Text(value,
                      style: pw.TextStyle(
                          fontSize: 11,
                          lineSpacing: 2,
                          fontWeight: pw.FontWeight.bold,
                          color: ink)),
                ],
              ),
            ),
          ],
        ),
      );

  static String _formatTotals(MoneyByCurrency totals) => totals.entries
      .map((money) => _formatMoney(money.minorUnits, money.currency))
      .join('\n');

  static String _pdfSafeText(String input) {
    const replacements = {
      '\u2018': "'",
      '\u2019': "'",
      '\u201c': '"',
      '\u201d': '"',
      '\u2013': '-',
      '\u2014': '-',
      '\u2212': '-',
      '\u2026': '...',
      '\u2022': '-',
      '\u00a0': ' ',
    };
    var output = input;
    for (final entry in replacements.entries) {
      output = output.replaceAll(entry.key, entry.value);
    }
    return output;
  }

  static String _formatMoney(int minorUnits, String currency) {
    var formatted = Money(minorUnits, currency).format();
    const replacements = {'€': 'EUR ', '£': 'GBP ', '¥': 'JPY ', '₹': 'INR '};
    for (final entry in replacements.entries) {
      formatted = formatted.replaceAll(entry.key, entry.value);
    }
    return formatted;
  }
}
