import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/clients/domain/client.dart';
import '../../features/clients/domain/client_repository.dart';
import '../../features/finance/domain/expense.dart';
import '../../features/finance/domain/finance_repository.dart';
import '../../features/finance/domain/income.dart';
import '../../features/work/domain/work_entry.dart';
import '../../features/work/domain/work_repository.dart';
import 'csv_writer.dart';

/// Exports every client, work entry, income record, and expense as
/// CSV — for backup, or handing off to an accountant (roadmap item 9).
/// All four files are produced in one pass and shared together so the
/// person picks one destination (Drive, email, Files) just once.
class CsvExportService {
  final ClientRepository clientRepository;
  final WorkRepository workRepository;
  final FinanceRepository financeRepository;

  CsvExportService({
    required this.clientRepository,
    required this.workRepository,
    required this.financeRepository,
  });

  static final _dateFmt = DateFormat('yyyy-MM-dd');

  Future<void> exportAll() async {
    final clients = await clientRepository.getAllClients();
    final clientNameById = {for (final c in clients) c.id: c.name};

    final workEntries = await workRepository.getAllEntries();
    final income = await financeRepository.getAllIncome();
    final expenses = await financeRepository.getAllExpenses();

    final files = <String, String>{
      'worklog_clients.csv': _clientsCsv(clients),
      'worklog_work_entries.csv': _workEntriesCsv(workEntries, clientNameById),
      'worklog_income.csv': _incomeCsv(income, clientNameById),
      'worklog_expenses.csv': _expensesCsv(expenses),
    };

    final dir = await getTemporaryDirectory();
    final xfiles = <XFile>[];
    for (final entry in files.entries) {
      final file = File('${dir.path}/${entry.key}');
      await file.writeAsString(entry.value);
      xfiles.add(XFile(file.path, mimeType: 'text/csv'));
    }

    await Share.shareXFiles(xfiles,
        subject: 'WorkLog data export (${_dateFmt.format(DateTime.now())})');
  }

  String _clientsCsv(List<Client> clients) {
    final csv = CsvWriter();
    csv.addRow([
      'Name',
      'Email',
      'Phone',
      'Total Earned',
      'Total Pending',
      'Retainer',
      'Retainer Amount',
      'Retainer Currency',
      'Retainer Day',
      'Notes'
    ]);
    for (final c in clients) {
      csv.addRow([
        c.name,
        c.email ?? '',
        c.phone ?? '',
        c.totalEarned.formatAll(),
        c.totalPending.formatAll(),
        c.isRetainer ? 'Yes' : 'No',
        c.retainerAmountMinor != null
            ? (c.retainerAmountMinor! / 100).toStringAsFixed(2)
            : '',
        c.retainerCurrency ?? '',
        c.retainerDayOfMonth?.toString() ?? '',
        c.notes ?? '',
      ]);
    }
    return csv.build();
  }

  String _workEntriesCsv(
      List<WorkEntry> entries, Map<String, String> clientNameById) {
    final csv = CsvWriter();
    csv.addRow([
      'Date',
      'Client',
      'Task',
      'Work Type',
      'Video Count',
      'Other Count',
      'Hours',
      'Status',
      'Notes'
    ]);
    for (final e in entries) {
      csv.addRow([
        _dateFmt.format(e.date),
        clientNameById[e.clientId] ?? '',
        e.taskName,
        e.workType,
        e.videoCount,
        e.otherTaskCount,
        e.hoursWorked.toStringAsFixed(2),
        e.status.label,
        e.notes ?? '',
      ]);
    }
    return csv.build();
  }

  String _incomeCsv(List<Income> income, Map<String, String> clientNameById) {
    final csv = CsvWriter();
    csv.addRow([
      'Date',
      'Client',
      'Amount',
      'Currency',
      'Method',
      'Description',
      'Notes'
    ]);
    for (final i in income) {
      csv.addRow([
        _dateFmt.format(i.date),
        clientNameById[i.clientId] ?? '',
        (i.amountMinor / 100).toStringAsFixed(2),
        i.currency,
        i.method,
        i.description ?? '',
        i.notes ?? '',
      ]);
    }
    return csv.build();
  }

  String _expensesCsv(List<Expense> expenses) {
    final csv = CsvWriter();
    csv.addRow(
        ['Date', 'Category', 'Amount', 'Currency', 'Description', 'Notes']);
    for (final e in expenses) {
      csv.addRow([
        _dateFmt.format(e.date),
        e.category,
        (e.amountMinor / 100).toStringAsFixed(2),
        e.currency,
        e.description ?? '',
        e.notes ?? '',
      ]);
    }
    return csv.build();
  }
}
