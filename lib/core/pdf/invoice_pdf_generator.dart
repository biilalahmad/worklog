import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/clients/domain/client.dart';
import '../../features/clients/domain/project.dart';
import '../utils/money.dart';

/// Creates a clean, print-first invoice PDF using the project's actual totals
/// and payment rollups. Invoice pages intentionally stay white regardless of
/// the app's selected theme.
class InvoicePdfGenerator {
  static const _navy = PdfColor.fromInt(0xFF1E3A5F);
  static const _sky = PdfColor.fromInt(0xFF5DB2F0);
  static const _ink = PdfColor.fromInt(0xFF1B2A41);
  static const _secondary = PdfColor.fromInt(0xFF5F7189);
  static const _line = PdfColor.fromInt(0xFFDCE5EF);
  static const _softBlue = PdfColor.fromInt(0xFFF1F6FB);

  static Future<void> generateAndShare({
    required Project project,
    required Client client,
    required String userName,
    String? paymentInstructions,
    String? email,
    String? professionalTitle,
    String? businessName,
    String? location,
    String? website,
  }) async {
    final bytes = await buildPdf(
      project: project,
      client: client,
      userName: userName,
      paymentInstructions: paymentInstructions,
      email: email,
      professionalTitle: professionalTitle,
      businessName: businessName,
      location: location,
      website: website,
    );
    final invoiceNumber = _invoiceNumber(project.id);
    final fileName =
        'Invoice_${project.title.replaceAll(RegExp(r'[^\w\-]+'), '_')}.pdf';
    final amount = _formatMoney(project.totalAmountMinor, project.currency);

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Invoice #$invoiceNumber from $userName',
      text:
          'Hi ${client.name}, please find attached invoice for ${project.title}. '
          'Total: $amount. Thank you!',
    );
  }

  /// Exposed separately so PDF layout and data can be verified without
  /// invoking the platform share sheet.
  static Future<Uint8List> buildPdf({
    required Project project,
    required Client client,
    required String userName,
    String? paymentInstructions,
    String? email,
    String? professionalTitle,
    String? businessName,
    String? location,
    String? website,
    DateTime? issuedAt,
  }) async {
    final doc = pw.Document();
    final logoBytes = (await rootBundle.load('assets/images/worklog_icon.png'))
        .buffer
        .asUint8List();
    final logo = pw.MemoryImage(logoBytes);
    final issued = issuedAt ?? DateTime.now();
    final dateFmt = DateFormat('MMM d, yyyy');
    final issuedTimeFmt = DateFormat('h:mm a');
    final invoiceNumber = _invoiceNumber(project.id);
    final sellerLines = <String>[
      if (_present(businessName) &&
          businessName!.trim().toLowerCase() != userName.trim().toLowerCase())
        userName.trim(),
      if (_present(professionalTitle)) professionalTitle!.trim(),
      if (_present(location)) location!.trim(),
      if (_present(website)) website!.trim(),
      if (_present(email)) email!.trim(),
    ];
    final clientLines = <String>[
      if (_present(client.email)) client.email!.trim(),
      if (_present(client.phone)) client.phone!.trim(),
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 38, 42, 42),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _line)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Thank you for your business',
                  style: const pw.TextStyle(fontSize: 9, color: _secondary)),
              pw.Text('WorkLog  |  $invoiceNumber',
                  style: const pw.TextStyle(fontSize: 9, color: _secondary)),
            ],
          ),
        ),
        build: (context) => [
          pw.Container(height: 5, color: _sky),
          pw.SizedBox(height: 22),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Image(logo, width: 40, height: 40),
                  pw.SizedBox(width: 10),
                  pw.Text('WorkLog',
                      style: const pw.TextStyle(
                          color: _navy,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: _softBlue,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text('#$invoiceNumber',
                    style: const pw.TextStyle(
                        color: _navy,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Text('INVOICE',
              style: const pw.TextStyle(
                  color: _ink,
                  fontSize: 34,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.1)),
          pw.SizedBox(height: 22),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: _partyBlock(
                  'FROM',
                  _firstPresent([businessName, userName]),
                  sellerLines,
                ),
              ),
              pw.SizedBox(width: 18),
              pw.Expanded(
                flex: 5,
                child: _partyBlock('BILL TO', client.name, clientLines),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _dateBlock('ISSUED',
                        '${dateFmt.format(issued)} at ${issuedTimeFmt.format(issued)}'),
                    if (project.dueDate != null) ...[
                      pw.SizedBox(height: 12),
                      _dateBlock('DUE', dateFmt.format(project.dueDate!)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 28),
          _lineItemTable(project),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PAYMENT STATUS', style: _eyebrowStyle()),
                    pw.SizedBox(height: 8),
                    _statusPill(project.displayStatus),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.SizedBox(
                width: 230,
                child: _totals(project),
              ),
            ],
          ),
          if (_present(paymentInstructions)) ...[
            pw.SizedBox(height: 24),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: _softBlue,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PAYMENT DETAILS', style: _eyebrowStyle()),
                  pw.SizedBox(height: 6),
                  pw.Text(paymentInstructions!.trim(),
                      style: const pw.TextStyle(fontSize: 9, color: _ink)),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 26),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _partyBlock(
      String label, String name, List<String> details) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: _eyebrowStyle()),
        pw.SizedBox(height: 7),
        pw.Text(name,
            style: const pw.TextStyle(
                color: _ink, fontSize: 11, fontWeight: pw.FontWeight.bold)),
        for (final detail in details)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(detail,
                style: const pw.TextStyle(fontSize: 8.5, color: _secondary)),
          ),
      ],
    );
  }

  static pw.Widget _dateBlock(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(label, style: _eyebrowStyle()),
          pw.SizedBox(height: 4),
          pw.Text(value,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 9, color: _secondary)),
        ],
      );

  static pw.Widget _lineItemTable(Project project) {
    final subtotal =
        _formatMoney(project.subtotalAmountMinor, project.currency);
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _softBlue),
          children: [
            _tableCell('DESCRIPTION', align: pw.TextAlign.left, header: true),
            _tableCell('QTY', header: true),
            _tableCell('RATE', header: true),
            _tableCell('AMOUNT', header: true),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line)),
          ),
          children: [
            _tableCell(project.title, align: pw.TextAlign.left),
            _tableCell('1'),
            _tableCell(subtotal),
            _tableCell(subtotal, bold: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableCell(String text,
      {pw.TextAlign align = pw.TextAlign.right,
      bool header = false,
      bool bold = false}) {
    return pw.Padding(
      padding:
          pw.EdgeInsets.symmetric(horizontal: 7, vertical: header ? 9 : 12),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: header ? _secondary : _ink,
          fontSize: header ? 7.5 : 9,
          fontWeight:
              header || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          letterSpacing: header ? .4 : 0,
        ),
      ),
    );
  }

  static pw.Widget _totals(Project project) {
    final rows = <pw.Widget>[
      _totalRow('Subtotal',
          _formatMoney(project.subtotalAmountMinor, project.currency)),
      if (project.taxAmountMinor != 0)
        _totalRow(
          '${project.taxLabel} (${project.taxRatePercent.toStringAsFixed(2)}%)',
          _formatMoney(project.taxAmountMinor, project.currency),
        ),
      pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Divider(color: _line),
      ),
      _totalRow(
          'Total', _formatMoney(project.totalAmountMinor, project.currency),
          bold: true),
      pw.SizedBox(height: 5),
      _totalRow(
          'Paid', _formatMoney(project.amountPaidMinor, project.currency)),
      _totalRow('Balance due',
          _formatMoney(project.amountRemainingMinor, project.currency),
          bold: true, color: _navy),
    ];
    return pw.Column(children: rows);
  }

  static pw.Widget _totalRow(String label, String value,
      {bool bold = false, PdfColor color = _secondary}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    color: bold ? color : _secondary,
                    fontSize: bold ? 10 : 9,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ),
          pw.SizedBox(width: 8),
          pw.Text(value,
              style: pw.TextStyle(
                  color: bold ? color : _ink,
                  fontSize: bold ? 10 : 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static pw.Widget _statusPill(ProjectStatus status) {
    final (label, background, foreground) = switch (status) {
      ProjectStatus.paid => (
          'PAID',
          const PdfColor.fromInt(0xFFE7F5EC),
          const PdfColor.fromInt(0xFF287A45)
        ),
      ProjectStatus.overdue => (
          'OVERDUE',
          const PdfColor.fromInt(0xFFFCEBE9),
          const PdfColor.fromInt(0xFFB33B32)
        ),
      ProjectStatus.partiallyPaid => (
          'PARTIALLY PAID',
          const PdfColor.fromInt(0xFFFFF3DE),
          const PdfColor.fromInt(0xFF956018)
        ),
      ProjectStatus.unpaid => ('UNPAID', _softBlue, _navy),
    };
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
          color: background, borderRadius: pw.BorderRadius.circular(20)),
      child: pw.Text(label,
          style: pw.TextStyle(
              color: foreground,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: .3)),
    );
  }

  static pw.TextStyle _eyebrowStyle() => const pw.TextStyle(
        color: _secondary,
        fontSize: 7.5,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: .7,
      );

  static bool _present(String? value) => value?.trim().isNotEmpty == true;

  static String _firstPresent(List<String?> values) =>
      values.firstWhere(_present, orElse: () => 'WorkLog User')!.trim();

  static String _invoiceNumber(String id) {
    final compact = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return compact.length >= 6
        ? compact.substring(compact.length - 6).toUpperCase()
        : compact.toUpperCase();
  }

  /// Helvetica's built-in PDF encoding does not include several currency
  /// glyphs. Replace those symbols with ISO codes so exported PDFs never show
  /// missing-glyph boxes while preserving the exact amount and currency.
  static String _formatMoney(int minorUnits, String currency) {
    var formatted = Money(minorUnits, currency).format();
    const replacements = {
      '€': 'EUR ',
      '£': 'GBP ',
      '¥': 'JPY ',
      '₹': 'INR ',
    };
    for (final entry in replacements.entries) {
      formatted = formatted.replaceAll(entry.key, entry.value);
    }
    return formatted;
  }
}
