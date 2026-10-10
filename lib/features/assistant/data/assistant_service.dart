import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/assistant_contract.dart';

class AssistantService {
  AssistantService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<AssistantReply> runTask({
    required AssistantTask task,
    required Map<String, Object?> context,
  }) async {
    late final FunctionResponse result;
    try {
      result = await _client.functions.invoke(
        'worklog-assistant',
        body: {
          'task': task.wireValue,
          'context': AssistantMetrics.sanitize(context),
        },
      );
    } on FunctionException catch (error) {
      final code = error.details is Map ? error.details['error'] : null;
      throw AssistantServiceException(_messageFor(code, error.status));
    } catch (_) {
      throw const AssistantServiceException(
          'Could not connect to the assistant. Check your connection and try again.');
    }
    if (result.status < 200 || result.status >= 300) {
      final code = result.data is Map ? result.data['error'] : null;
      if (code == 'assistant_not_configured') {
        throw const AssistantServiceException(
            'The assistant is still being configured. Please try again later.');
      }
      if (code == 'rate_limited') {
        throw const AssistantServiceException(
            'The free AI limit has been reached. Please try again later.');
      }
      throw AssistantServiceException(_messageFor(code, result.status));
    }
    if (result.data is! Map<String, dynamic>) {
      throw const FormatException(
          'The assistant returned an invalid response.');
    }
    return AssistantReply.fromJson(result.data as Map<String, dynamic>);
  }

  String _messageFor(Object? code, int status) {
    if (code == 'assistant_not_configured') {
      return 'The assistant is still being configured. Please try again later.';
    }
    if (code == 'rate_limited' || status == 429) {
      return 'The free AI request limit has been reached. Please try again later.';
    }
    if (status == 0) {
      return 'Could not connect to the assistant. Check your connection and try again.';
    }
    return 'The AI service is temporarily unavailable. Your saved data is safe; please try again.';
  }
}

class AssistantServiceException implements Exception {
  const AssistantServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
