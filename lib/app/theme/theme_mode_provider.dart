import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const themeModePreferenceKey = 'worklog.theme_mode';

ThemeMode themeModeFromPreference(String? value) => switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

/// Keeps the user's appearance choice across app restarts.
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
    (ref) => ThemeModeController(ThemeMode.system, null));

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(super.initialMode, this._preferences);

  final SharedPreferences? _preferences;

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _preferences?.setString(themeModePreferenceKey, mode.name);
  }
}
