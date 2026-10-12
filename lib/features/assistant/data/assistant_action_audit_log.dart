import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small on-device audit trail for assistant-executed writes. It deliberately
/// stores only action type, local record id and timestamp, not user content.
class AssistantActionAuditLog {
  static const _key = 'worklog_assistant_action_audit_v1';

  Future<void> record({required String action, required String id}) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_key) ?? <String>[];
    entries.add(jsonEncode({
      'action': action,
      'id': id,
      'at': DateTime.now().toIso8601String(),
    }));
    await preferences.setStringList(_key,
        entries.length > 100 ? entries.sublist(entries.length - 100) : entries);
  }
}
