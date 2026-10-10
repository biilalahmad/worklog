import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../features/clients/domain/client.dart';
import '../../features/finance/domain/finance_repository.dart';
import '../../features/finance/domain/income.dart';
import 'csv_writer.dart';

class CsvImportResult {
  final int imported;
  final int skipped;
  final List<String> skipReasons;
  const CsvImportResult({required this.imported, required this.skipped, required this.skipReasons});
}

/// Imports income records from a CSV file — same column layout
/// CsvExportService produces (Date, Client, Amount, Currency, Method,
/// Description, Notes), so export → edit in a spreadsheet → re-import
/// is a smooth round trip. Each row's "Client" is matched by exact
/// name (case-insensitive) against the clients already in the app;
/// unmatched rows are skipped rather than guessed at.
class CsvImportService {
  final FinanceRepository financeRepository;
  CsvImportService({required this.financeRepository});

  /// Returns null if the user cancelled the file picker.
  Future<CsvImportResult?> importIncomeCsv(List<Client> existingClients) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final String content;
    if (picked.bytes != null) {
      content = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      content = await File(picked.path!).readAsString();
    } else {
      return const CsvImportResult(imported: 0, skipped: 0, skipReasons: ["Couldn't read the selected file."]);
    }

    final rows = parseCsv(content);
    if (rows.isEmpty) return const CsvImportResult(imported: 0, skipped: 0, skipReasons: []);

    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
    int col(String name) => header.indexOf(name);
    final dateCol = col('date');
    final clientCol = col('client');
    final amountCol = col('amount');
    final currencyCol = col('currency');
    final methodCol = col('method');
    final descCol = col('description');
    final notesCol = col('notes');

    if (dateCol == -1 || clientCol == -1 || amountCol == -1) {
      return const CsvImportResult(
        imported: 0,
        skipped: 0,
        skipReasons: ['CSV must have Date, Client and Amount columns (same layout as the exported file).'],
      );
    }

    final clientsByName = {for (final c in existingClients) c.name.trim().toLowerCase(): c};

    var imported = 0;
    final skipReasons = <String>[];

    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      String cell(int i) => (i >= 0 && i < row.length) ? row[i].trim() : '';

      final clientName = cell(clientCol);
      final client = clientsByName[clientName.toLowerCase()];
      if (client == null) {
        skipReasons.add('Row ${r + 1}: no client named "$clientName"');
        continue;
      }
      final date = DateTime.tryParse(cell(dateCol));
      final amount = double.tryParse(cell(amountCol));
      if (date == null || amount == null) {
        skipReasons.add('Row ${r + 1}: invalid date or amount');
        continue;
      }

      try {
        await financeRepository.addIncome(Income(
          id: '',
          clientId: client.id,
          amountMinor: (amount * 100).round(),
          currency: currencyCol != -1 && cell(currencyCol).isNotEmpty ? cell(currencyCol) : 'PKR',
          date: date,
          method: methodCol != -1 && cell(methodCol).isNotEmpty ? cell(methodCol) : 'Other',
          description: descCol != -1 && cell(descCol).isNotEmpty ? cell(descCol) : null,
          notes: notesCol != -1 && cell(notesCol).isNotEmpty ? cell(notesCol) : null,
        ));
        imported++;
      } catch (e) {
        skipReasons.add('Row ${r + 1}: $e');
      }
    }

    return CsvImportResult(imported: imported, skipped: skipReasons.length, skipReasons: skipReasons);
  }
}
