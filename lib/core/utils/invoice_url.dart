import '../config/app_info.dart';

/// Creates the absolute public invoice URL for native and web clients alike.
String buildInvoiceUrl(String token) {
  final base = Uri.parse(AppInfo.invoiceBaseUrl);
  if (base.scheme != 'https' || base.host.isEmpty) {
    throw StateError('INVOICE_BASE_URL must be an HTTPS URL.');
  }

  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/invoice/',
    queryParameters: {'token': token},
  ).toString();
}
