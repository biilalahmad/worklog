import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:worklog/core/errors/failure.dart';

void main() {
  test('explains an unavailable exchange-rate function', () {
    final failure = Failure.from(const FunctionsHttpException(
      status: 503,
      details: '{"error":"rates_unavailable"}',
    ));

    expect(failure.code, 'rates_provider_unavailable');
    expect(failure.message, contains('Exchange rates could not be loaded'));
    expect(failure.message, isNot(contains('Something went wrong')));
  });

  test('explains a missing deployed edge function', () {
    final failure = Failure.from(const FunctionsHttpException(status: 404));
    expect(failure.message, contains('not deployed'));
  });

  test('uses the shared message for Auth rate limits', () {
    final failure = Failure.from(const AuthException(
      'Too many requests',
      statusCode: '429',
    ));

    expect(failure.code, Failure.codeRateLimited);
    expect(failure.message, Failure.tooManyRequests);
  });

  test('uses the shared message for Edge Function HTTP 429 responses', () {
    final failure = Failure.from(const FunctionsHttpException(
      status: 429,
      details: '{"error":"some_endpoint_error"}',
    ));

    expect(failure.code, Failure.codeRateLimited);
    expect(failure.message, Failure.tooManyRequests);
  });

  test('explains missing backend tables with the error code', () {
    final failure = Failure.from(const PostgrestException(
      message: 'relation missing',
      code: '42P01',
    ));
    expect(failure.message, contains('table is missing'));
    expect(failure.message, contains('42P01'));
  });

  test('explains project income currency mismatches', () {
    final failure = Failure.from(const PostgrestException(
      message: 'Income project currency mismatch.',
      code: '23514',
    ));

    expect(failure.code, 'project_currency_mismatch');
    expect(failure.message, contains('project’s currency'));
  });
}
