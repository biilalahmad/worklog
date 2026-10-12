import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A typed failure with a friendly, English, user-facing message.
/// Every Supabase / network exception is mapped through here so raw
/// error text (and internals) never reach the UI.
class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  // Canonical messages (kept in one place so the whole app is consistent).
  static const noInternet = 'No internet connection. Please try again.';
  static const generic = 'We couldn’t complete that request. Please try again.';
  static const saveFailed = 'Couldn’t save this change. Please try again.';
  static const saveOffline = 'You’re offline. Reconnect and try again.';
  static const pdfFailed = "Couldn't generate PDF. Please try again.";
  static const tooManyRequests = 'Too many requests, Please try again later.';

  static const codeUnconfirmed = 'auth_unconfirmed';
  static const codeInvalid = 'auth_invalid';
  static const codeConflict = 'auth_conflict';
  static const codeRateLimited = 'auth_rate_limited';
  static const codeExpired = 'auth_link_expired';
  static const codeNetwork = 'network';

  bool get isNetwork => code == codeNetwork;
  bool get isUnconfirmed => code == codeUnconfirmed;

  factory Failure.from(Object error) {
    if (error is Failure) return error;

    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      final status = error.statusCode?.toString();

      if (_looksOffline(msg)) {
        return const Failure(noInternet, code: codeNetwork);
      }
      if (msg.contains('email not confirmed') ||
          msg.contains('not confirmed')) {
        return const Failure('Please verify your email before logging in.',
            code: codeUnconfirmed);
      }
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials')) {
        // Never reveal which field was wrong.
        return const Failure('Incorrect email or password', code: codeInvalid);
      }
      if (msg.contains('already registered') ||
          msg.contains('already exists')) {
        return const Failure(
          'An account with this email already exists. Try logging in instead.',
          code: codeConflict,
        );
      }
      if (msg.contains('password should be') || msg.contains('weak password')) {
        return const Failure('Password must be at least 8 characters.',
            code: 'auth_weak_password');
      }
      if (status == '429' ||
          msg.contains('rate limit') ||
          msg.contains('too many')) {
        return const Failure(tooManyRequests, code: codeRateLimited);
      }
      if (msg.contains('expired') || msg.contains('invalid or has expired')) {
        return const Failure('This link has expired. Request a new one.',
            code: codeExpired);
      }
      return const Failure(generic, code: 'auth_error');
    }

    if (error is FunctionException) {
      final details = error.details;
      final detailMap = details is Map
          ? details
          : details is String
              ? _decodeJsonMap(details)
              : null;
      final detailCode = detailMap?['error']?.toString();
      if (error.status == 0 || _looksOffline('$details'.toLowerCase())) {
        return const Failure(noInternet, code: codeNetwork);
      }
      if (error.status == 429) {
        return const Failure(tooManyRequests, code: codeRateLimited);
      }
      if (detailCode == 'rates_not_configured') {
        return const Failure(
          'Exchange-rate API key is missing. Add EXCHANGE_RATE_API_KEY to Supabase Edge Function Secrets.',
          code: 'rates_not_configured',
        );
      }
      if (detailCode == 'rates_cache_unavailable') {
        return const Failure(
          'The shared exchange-rate cache is not ready. Apply the exchange-rate cache SQL migration in Supabase.',
          code: 'rates_cache_unavailable',
        );
      }
      if (detailCode == 'rates_provider_unavailable' ||
          detailCode == 'rates_unavailable') {
        return const Failure(
          'Exchange rates could not be loaded. Check the API key, provider quota, and exchange-rates function logs.',
          code: 'rates_provider_unavailable',
        );
      }
      if (detailCode == 'authentication_required' || error.status == 401) {
        return const Failure(
            'Your session could not be verified. Sign in again and retry.',
            code: 'function_auth');
      }
      if (error.status == 404) {
        return const Failure(
            'The server function is not deployed at this endpoint.',
            code: 'function_not_deployed');
      }
      if (error.status >= 500) {
        return Failure(
          'The server function returned HTTP ${error.status}. Check its Supabase logs for the request error.',
          code: 'function_${error.status}',
        );
      }
      return Failure('The server rejected the request (HTTP ${error.status}).',
          code: 'function_${error.status}');
    }

    if (error is PostgrestException) {
      switch (error.code) {
        case '23514':
          if (error.message.toLowerCase().contains('project currency')) {
            return const Failure(
              'Income linked to a project must use that project’s currency.',
              code: 'project_currency_mismatch',
            );
          }
          break;
        case '23505':
          return const Failure('This record already exists.', code: 'conflict');
        case '23503':
          return const Failure(
            "This can't be completed because a linked record still exists.",
            code: 'constraint',
          );
        case 'PGRST116':
          return const Failure('Record not found.', code: 'not_found');
        case '42501':
          return const Failure('You don’t have permission to do that.',
              code: 'permission');
        case '42P01':
        case 'PGRST205':
          return Failure(
              'A required database table is missing or not exposed to the Data API (${error.code}).',
              code: error.code);
        case '42703':
        case 'PGRST204':
          return Failure(
              'The database is missing a column required by this app (${error.code}).',
              code: error.code);
        case 'PGRST202':
          return Failure(
              'A required database function is not installed (${error.code}).',
              code: error.code);
      }
      if (_looksOffline(error.message.toLowerCase())) {
        return const Failure(
            'You’re offline. Please try connecting to the internet.',
            code: codeNetwork);
      }
      return Failure(
          'The database rejected this request (${error.code ?? 'unknown code'}).',
          code: error.code);
    }

    if (error is TimeoutException ||
        _looksOffline(error.toString().toLowerCase())) {
      return const Failure(
          'You’re offline. Please try connecting to the internet.',
          code: codeNetwork);
    }
    return const Failure(generic);
  }

  factory Failure.save(Object error) {
    final f = Failure.from(error);
    if (f.isNetwork) return const Failure(saveOffline, code: codeNetwork);
    if (f.code != null && f.message != generic) return f;
    return Failure('$saveFailed ${f.message}');
  }

  static bool _looksOffline(String text) =>
      text.contains('socketexception') ||
      text.contains('timeoutexception') ||
      text.contains('failed host lookup') ||
      text.contains('failed to fetch') ||
      text.contains('network is unreachable') ||
      text.contains('connection reset') ||
      text.contains('clientexception') ||
      text.contains('network') ||
      text.contains('timeout') ||
      text.contains('connection refused');

  static Map<String, dynamic>? _decodeJsonMap(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => message;
}
