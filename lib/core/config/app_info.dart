/// Keep in sync with the `version:` line in pubspec.yaml — shown on
/// Profile > About. (Not read from the package at runtime so this
/// works identically on every platform without an extra plugin.)
class AppInfo {
  AppInfo._();
  static const version = '0.5.3';
  static const privacyPolicyUrl = 'https://worklog-site.netlify.app/privacy/';
  static const termsOfServiceUrl = 'https://worklog-site.netlify.app/terms/';
  static const invoiceBaseUrl = String.fromEnvironment(
    'INVOICE_BASE_URL',
    defaultValue: 'https://worklog-site.netlify.app',
  );
  static const supportEmail = 'worklog.support@gmail.com';
}
