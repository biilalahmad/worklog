import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/core/utils/invoice_url.dart';

void main() {
  test('builds a secure public invoice URL with the token as a query value',
      () {
    const token = '53be67f4-8a3a-49fc-aa0e-5f64239cd3f2';

    final invoiceUrl = buildInvoiceUrl(token);
    final uri = Uri.parse(invoiceUrl);

    expect(
      invoiceUrl,
      'https://worklog-site.netlify.app/invoice/?token=$token',
    );
    expect(invoiceUrl, startsWith('https://'));
    expect(uri.scheme, 'https');
    expect(uri.host, 'worklog-site.netlify.app');
    expect(uri.path, '/invoice/');
    expect(uri.queryParameters['token'], token);
    expect(token, matches(RegExp(r'^[A-Fa-f0-9-]+$')));
  });
}
