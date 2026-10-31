import '../models/tank_config.dart';
import '../models/tank_level.dart';
import '../models/tank_reading.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'tank_rules.dart';

/// The outcome of judging one reading.
class Evaluation {
  const Evaluation(this.level, this.alert);

  final TankLevel level;

  /// Set when this reading crossed into full or empty.
  final AlertEntry? alert;
}

/// Judges a reading against the last known state, and raises the
/// notification when it crossed a threshold.
///
/// The single path for both the dashboard and the Android background check.
/// The last state lives in preferences rather than in memory, so a tank that
/// filled while the app was closed is announced once by the background check
/// and not again when the dashboard next opens.
class TankEvaluator {
  static Future<Evaluation> evaluate(
    TankReading reading,
    TankConfig config,
  ) async {
    final previous = await SettingsService.getLastLevel();
    final level = classifyLevel(
      reading.percent,
      config,
      previous: previous,
      floatFull: reading.floatFull,
    );
    final kind = alertFor(previous: previous, current: level);

    if (level != previous) await SettingsService.setLastLevel(level);
    if (kind == null) return Evaluation(level, null);

    final entry = AlertEntry(
      kind: kind,
      percent: reading.percent,
      at: reading.measuredAt,
    );
    await SettingsService.addAlert(entry);
    if (config.notificationsEnabled) {
      await NotificationService.showAlert(
        kind,
        reading.percent,
        // Full by the float alone: say so, or the percent looks contradictory.
        byFloat:
            reading.floatFull == true && reading.percent < config.fullThreshold,
      );
    }
    return Evaluation(level, entry);
  }
}
