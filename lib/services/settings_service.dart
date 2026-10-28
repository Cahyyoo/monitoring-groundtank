import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tank_config.dart';
import '../models/tank_level.dart';

/// Everything kept on the device.
///
/// The dashboard and the Android background check run in different isolates,
/// each with its own SharedPreferences cache. Anything both of them write —
/// the last state and the alert log — is read after [SharedPreferences.reload]
/// so one never acts on what the other has already changed.
class SettingsService {
  static const _configKey = 'gt_config';
  static const _themeKey = 'gt_theme_mode';
  static const _lastLevelKey = 'gt_last_level';
  static const _alertsKey = 'gt_alerts';
  static const _alertsSeenKey = 'gt_alerts_seen_at';

  /// How many alerts the Notifikasi tab keeps.
  static const maxAlerts = 50;

  static Future<TankConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_configKey);
      if (raw == null) return const TankConfig();
      return TankConfig.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      // An unreadable store must not keep the app from starting; the defaults
      // are a working (demo) setup.
      return const TankConfig();
    }
  }

  static Future<void> saveConfig(TankConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  /// Null means "follow the device".
  static Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeKey);
    if (stored != 'light' && stored != 'dark') return null;
    return stored;
  }

  static Future<void> setThemeMode(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_themeKey);
    } else {
      await prefs.setString(_themeKey, value);
    }
  }

  /// The state the tank was in at the last check, from either isolate.
  static Future<TankLevel?> getLastLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final stored = prefs.getString(_lastLevelKey);
    return TankLevel.values.where((l) => l.name == stored).firstOrNull;
  }

  static Future<void> setLastLevel(TankLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastLevelKey, level.name);
  }

  /// Forgets the last state, so the next reading is judged afresh. Used when
  /// the source or the thresholds change.
  static Future<void> clearLastLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastLevelKey);
  }

  /// Newest first.
  static Future<List<AlertEntry>> getAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getStringList(_alertsKey) ?? const [];
    return [for (final row in raw) ?_decodeAlert(row)];
  }

  static Future<void> addAlert(AlertEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getStringList(_alertsKey) ?? const [];
    final next = [jsonEncode(entry.toJson()), ...raw].take(maxAlerts).toList();
    await prefs.setStringList(_alertsKey, next);
  }

  static Future<void> clearAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_alertsKey);
  }

  /// When the Notifikasi tab was last opened, for the unread badge.
  static Future<DateTime?> getAlertsSeenAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_alertsSeenKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setAlertsSeenAt(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_alertsSeenKey, at.millisecondsSinceEpoch);
  }

  static AlertEntry? _decodeAlert(String row) {
    try {
      return AlertEntry.tryParse(
        (jsonDecode(row) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return null;
    }
  }
}
