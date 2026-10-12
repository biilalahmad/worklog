import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pdf/invoice_file_service.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/clients/domain/client.dart';
import '../../features/clients/domain/project.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../pdf/invoice_pdf_generator.dart';

/// The per-project invoice download icon used on both the Client Detail
/// and Pending Payments screens (Section 4.1 of the spec) — one shared
/// implementation so both stay in sync: same PDF and invoice name.
class InvoiceDownloadButton extends ConsumerStatefulWidget {
  final Project project;
  final Client client;
  final double iconSize;

  const InvoiceDownloadButton({
    super.key,
    required this.project,
    required this.client,
    this.iconSize = 20,
  });

  @override
  ConsumerState<InvoiceDownloadButton> createState() =>
      _InvoiceDownloadButtonState();
}

class _InvoiceDownloadButtonState extends ConsumerState<InvoiceDownloadButton> {
  final InvoiceFileService _fileService = InvoiceFileService();
  bool _saving = false;

  Future<Uint8List> _buildInvoice() async {
    final profile = ref.read(profileProvider).valueOrNull;
    final email = ref.read(authRepositoryProvider).currentUserEmail;
    final displayName =
        profile?.effectiveInvoiceName ?? email ?? 'WorkLog User';
    final bytes = await InvoicePdfGenerator.buildPdf(
      project: widget.project,
      client: widget.client,
      userName: displayName,
      paymentInstructions: profile?.paymentInstructions,
      email: email,
      professionalTitle: profile?.professionalTitle,
      businessName: profile?.businessName,
      location: profile?.location,
      website: profile?.website,
    );
    return bytes;
  }

  Future<void> _download() async {
    setState(() => _saving = true);
    try {
      final bytes = await _buildInvoice();
      final uri = await _fileService.saveToDownloads(
        fileName: InvoicePdfGenerator.fileNameFor(widget.project),
        bytes: bytes,
      );
      if (mounted) {
        final isAndroid = Theme.of(context).platform == TargetPlatform.android;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isAndroid ? 'Saved to Downloads' : 'Invoice PDF saved'),
            action: isAndroid
                ? SnackBarAction(
                    label: 'Open',
                    onPressed: () => _openSavedPdf(uri),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_saveErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSavedPdf(String uri) async {
    try {
      await _fileService.openSavedPdf(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the saved PDF.')),
        );
      }
    }
  }

  String _saveErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('STORAGE_PERMISSION_DENIED')) {
      return 'Storage permission is needed to save files on Android 9 and older.';
    }
    if (message.contains('Invoice save was cancelled')) {
      return 'Invoice download cancelled.';
    }
    return 'Could not save the invoice PDF. Check available storage and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: 'Download PDF',
        onPressed: _saving ? null : _download,
        icon: _saving
            ? SizedBox(
                width: widget.iconSize,
                height: widget.iconSize,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.download_rounded, size: widget.iconSize),
      ),
    );
  }
}
