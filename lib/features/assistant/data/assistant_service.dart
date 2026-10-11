import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../domain/assistant_contract.dart';

class AssistantService {
  AssistantService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<AssistantReply> runTask({
    required AssistantTask task,
    required Map<String, Object?> context,
  }) =>
      _invoke({
        'task': task.wireValue,
        'context': AssistantMetrics.sanitize(context),
      });

  Future<AssistantReply> chat({
    required String message,
    required List<Map<String, String>> history,
    required Map<String, Object?> context,
  }) {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return _invoke({
      'message': message.trim(),
      'history': history.take(8).toList(growable: false),
      'localNow': '${now.toIso8601String()}$sign$hours:$minutes',
      'context': AssistantMetrics.sanitize(context),
    });
  }

  Future<AssistantReply> _invoke(Map<String, Object?> body) async {
    late final FunctionResponse result;
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        result = await _client.functions
            .invoke('worklog-assistant', body: body)
            .timeout(const Duration(seconds: 27));
        lastError = null;
        break;
      } on FunctionException catch (error) {
        final code = error.details is Map ? error.details['error'] : null;
        if (attempt == 0 && (error.status == 502 || error.status == 503)) {
          lastError = error;
          await Future<void>.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw AssistantServiceException(_messageFor(code, error.status));
      } on TimeoutException catch (error) {
        lastError = error;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw const AssistantServiceException(
            'WorkLog AI took too long to respond. Please check your connection and try again.');
      } catch (error) {
        lastError = error;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw const AssistantServiceException(
            'Could not connect to WorkLog AI. Check your connection and try again.');
      }
    }
    if (lastError != null) {
      throw const AssistantServiceException(
          'WorkLog AI is temporarily unavailable. Please try again.');
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
