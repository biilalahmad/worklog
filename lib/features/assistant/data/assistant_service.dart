import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../../core/utils/backend_connection.dart';
import '../domain/assistant_contract.dart';
import '../domain/agent_contract.dart';

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

  Future<AssistantAgentReply> agentChat({
    required String message,
    required List<Map<String, String>> history,
    required Map<String, Object?> context,
    required Map<String, Object?> agentContext,
    Map<String, Object?>? draft,
  }) async {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final body = <String, Object?>{
      'message': message.trim(),
      'history': history.take(6).map((turn) {
        final text = turn['text'] ?? '';
        return <String, String>{
          'role': turn['role'] ?? '',
          'text': text.length > 500 ? text.substring(0, 500) : text,
        };
      }).toList(growable: false),
      'localNow': '${now.toIso8601String()}$sign$hours:$minutes',
      'context': AssistantMetrics.sanitize(context),
      'agentContext': agentContext,
      if (draft != null) 'draft': draft,
    };
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await _invokeData({
        ...body,
        if (attempt > 0) 'schemaRetry': true,
      });
      try {
        return AssistantAgentReply.fromJson(response);
      } on FormatException {
        if (attempt == 1) {
          throw const AssistantServiceException(
              'WorkLog AI returned an invalid action. Nothing was changed; please try again.');
        }
      }
    }
    throw const AssistantServiceException(
        'WorkLog AI could not prepare a safe response. Please try again.');
  }

  Future<AssistantReply> _invoke(Map<String, Object?> body) async {
    final data = await _invokeData(body);
    return AssistantReply.fromJson(data);
  }

  Future<Map<String, dynamic>> _invokeData(Map<String, Object?> body) async {
    late final FunctionResponse result;
    try {
      // The Edge Function owns its single bounded upstream attempt. Retrying a
      // slow 503 here doubled the wait and could make one tap take nearly a
      // minute on an unstable connection.
      result = await _client.functions
          .invoke('worklog-assistant', body: body)
          .timeout(const Duration(seconds: 16));
      BackendConnection.instance.reportAvailable();
    } on FunctionException catch (error) {
      if (error.status == 0 || error.status >= 500) {
        BackendConnection.instance.reportUnavailable();
      }
      final code = error.details is Map ? error.details['error'] : null;
      throw AssistantServiceException(_messageFor(code, error.status));
    } on TimeoutException {
      BackendConnection.instance.reportUnavailable();
      throw const AssistantServiceException(
          'WorkLog AI took too long to respond. You can still ask basic app questions offline.');
    } catch (_) {
      BackendConnection.instance.reportUnavailable();
      throw const AssistantServiceException(
          'Could not connect to WorkLog AI. Check your connection and try again.');
    }
    if (result.status < 200 || result.status >= 300) {
      final code = result.data is Map ? result.data['error'] : null;
      if (result.status >= 500) {
        BackendConnection.instance.reportUnavailable();
      }
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
    return result.data as Map<String, dynamic>;
  }

  String _messageFor(Object? code, int status) {
    if (code == 'assistant_not_configured') {
      return 'The assistant is still being configured. Please try again later.';
    }
    if (code == 'rate_limited' || status == 429) {
      return 'The free AI request limit has been reached. Please try again later.';
    }
    if (code == 'assistant_timeout' || status == 504) {
      return 'WorkLog AI took too long to respond. You can still ask basic app questions offline.';
    }
    if (code == 'assistant_auth_failed') {
      return 'WorkLog AI is temporarily unavailable. Basic app help is still available offline.';
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
