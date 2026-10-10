import 'package:flutter/foundation.dart' show kIsWeb;

/// Supabase project credentials + auth deep-link settings.
///
/// Pass them at build/run time so real keys never get committed:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=xxxxx \
///     --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
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

  /// OAuth *Web* client ID from Google Cloud Console (used as the
  /// `serverClientId` so Supabase can verify the Google ID token).
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Optional iOS client ID (only needed if/when an iOS build ships).
  static const String googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !url.contains('YOUR-PROJECT') &&
      !anonKey.contains('YOUR-ANON-KEY');

  static bool get isGoogleConfigured => kIsWeb || googleWebClientId.isNotEmpty;

  /// Deep links the email templates redirect back into the app with.
  /// Add BOTH to Supabase Dashboard -> Authentication -> URL Configuration
  /// -> Redirect URLs.
  static const String authRedirect = 'io.worklog.app://login-callback/';
  static const String resetRedirect = 'io.worklog.app://reset-callback/';

  /// Email confirmation returns to the Flutter web app's mounted path.
  /// The public marketing site lives at the origin root.
  static String get webAuthRedirect => '${Uri.base.origin}/app/';
}
