import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings_service.dart';

/// Which appearance the app uses, [ThemeMode.system] unless chosen otherwise.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    // Watched by the root widget: an escaping error would surface before the
    // first frame, and the fallback is already the right answer.
    try {
      state = _parse(await SettingsService.getThemeMode());
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode value) async {
    state = value;
    await SettingsService.setThemeMode(switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    });
  }

  static ThemeMode _parse(String? stored) => switch (stored) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});
