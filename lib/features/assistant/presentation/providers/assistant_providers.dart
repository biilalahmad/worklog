import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/assistant_service.dart';

final assistantServiceProvider =
    Provider<AssistantService>((ref) => AssistantService());

const assistantConsentKey = 'worklog_assistant_external_ai_consent_v1';

final assistantConsentProvider = FutureProvider<bool>((ref) async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getBool(assistantConsentKey) ?? false;
});

final assistantConsentControllerProvider =
    Provider<AssistantConsentController>((ref) {
  return AssistantConsentController(ref);
});

class AssistantConsentController {
  const AssistantConsentController(this._ref);
  final Ref _ref;

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(assistantConsentKey, enabled);
    _ref.invalidate(assistantConsentProvider);
  }
}
