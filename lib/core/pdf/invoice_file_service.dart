import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Saves invoice PDFs to Android Downloads, or uses the platform save dialog
/// on desktop/web. The Android implementation uses MediaStore on API 29+.
class InvoiceFileService {
  static const _channel = MethodChannel(
    'com.example.freelance_tracker/invoice_files',
  );

  Future<String> saveToDownloads({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final uri = await _channel.invokeMethod<String>('savePdfToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
      });
      if (uri == null || uri.isEmpty) {
        throw StateError('The saved invoice did not return a file location.');
      }
      return uri;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save invoice PDF',
      fileName: fileName,
      bytes: bytes,
    );
    if (path == null || path.isEmpty) {
      throw StateError('Invoice save was cancelled.');
    }
    return path;
  }

  Future<void> openSavedPdf(String uri) =>
      _channel.invokeMethod<void>('openPdf', {'uri': uri});
}
