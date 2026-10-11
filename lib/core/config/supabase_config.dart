/// Supabase project credentials + auth deep-link settings.
///
/// Pass them at build/run time so real keys never get committed:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=xxxxx
///
/// Only the public "anon" key ever belongs in the app. Never put the
/// service-role key here — it bypasses Row Level Security entirely.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wezelfoysutywpaqofhe.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlemVsZm95c3V0eXdwYXFvZmhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3NDUyNDIsImV4cCI6MjEwNjMyMTI0Mn0.QrsRYUyp9cKoMTxb8ZV6_GmOMns2ALc-40dcZmczxKQ',
  );

  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !url.contains('YOUR-PROJECT') &&
      !anonKey.contains('YOUR-ANON-KEY');

  /// Android app-return auth callbacks; signup verification uses the public
  /// website route below. Keep both links in Supabase's redirect allow-list.
  static const String authRedirect = 'io.worklog.app://login-callback/';
  static const String resetRedirect = 'io.worklog.app://reset-callback/';
  static const String verificationRedirect = String.fromEnvironment(
    'EMAIL_VERIFICATION_REDIRECT_URL',
    defaultValue: 'https://worklog-site.netlify.app/verified/',
  );
}
