import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/clients/domain/client.dart';
import '../../features/clients/domain/project.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../errors/failure.dart';
import '../pdf/invoice_pdf_generator.dart';

/// The per-project invoice download icon used on both the Client Detail
/// and Pending Payments screens (Section 4.1 of the spec) — one shared
/// implementation so both stay in sync: same PDF, same invoice name,
/// same payment-instructions text, same share sheet.
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
  bool _generating = false;

  Future<void> _download() async {
    setState(() => _generating = true);
    try {
      final profile = ref.read(profileProvider).valueOrNull;
      final displayName = profile?.effectiveInvoiceName ??
          ref.read(authRepositoryProvider).currentUserEmail ??
          'WorkLog User';
      await InvoicePdfGenerator.generateAndShare(
        project: widget.project,
        client: widget.client,
        userName: displayName,
        paymentInstructions: profile?.paymentInstructions,
        email: ref.read(authRepositoryProvider).currentUserEmail,
        professionalTitle: profile?.professionalTitle,
        businessName: profile?.businessName,
        location: profile?.location,
        website: profile?.website,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(Failure.pdfFailed)));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_generating) {
      return SizedBox(
        width: widget.iconSize + 20,
        height: widget.iconSize + 20,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: Icon(Icons.download_rounded, size: widget.iconSize),
      tooltip: 'Download invoice PDF',
      onPressed: _download,
    );
  }
}
