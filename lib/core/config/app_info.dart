/// Keep in sync with the `version:` line in pubspec.yaml — shown on
/// Profile > About. (Not read from the package at runtime so this
/// works identically on every platform without an extra plugin.)
class AppInfo {
  AppInfo._();
  static const version = '0.5.0';
  static const privacyPolicyUrl = 'https://worklog-site.netlify.app/privacy/';
  static const termsOfServiceUrl = 'https://worklog-site.netlify.app/terms/';
  static const supportEmail = 'worklog.support@gmail.com';
}
