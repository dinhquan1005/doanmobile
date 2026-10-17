import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/firebase_providers.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_loadInitialThemeMode(_prefs));

  final SharedPreferences? _prefs;

  static ThemeMode _loadInitialThemeMode(SharedPreferences? prefs) {
    if (prefs == null) {
      return ThemeMode.system;
    }
    final saved = prefs.getString(AppConstants.prefThemeModeKey);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(AppConstants.prefThemeModeKey, mode.name);
    }
  }

  Future<void> toggleLightDark() async {
    final nextMode =
    state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }
}

final themeModeProvider =
StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    prefs = null;
  }
  return ThemeModeNotifier(prefs);
});