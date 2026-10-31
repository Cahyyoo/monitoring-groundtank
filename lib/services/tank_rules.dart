import '../models/tank_config.dart';
import '../models/tank_level.dart';
import '../models/tank_reading.dart';

/// How far back past a threshold the level must fall before the state lets
/// go of it, in percentage points.
///
/// Without it, water sloshing around 90% flips full → normal → full every few
/// seconds, and each flip into full is a fresh notification.
const double hysteresisPercent = 3;

/// Which state [percent] puts the tank in, given the state it was in before.
///
/// A lifted float switch ([floatFull]) is full whatever the level sensor
/// says: it is the more direct of the two, and an overflow costs more than a
/// false alarm.
TankLevel classifyLevel(
  double percent,
  TankConfig config, {
  TankLevel? previous,
  bool? floatFull,
}) {
  if (floatFull == true || percent >= config.fullThreshold) {
    return TankLevel.full;
  }
  if (percent <= config.emptyThreshold) return TankLevel.empty;
  if (previous == TankLevel.full &&
      percent > config.fullThreshold - hysteresisPercent) {
    return TankLevel.full;
  }
  if (previous == TankLevel.empty &&
      percent < config.emptyThreshold + hysteresisPercent) {
    return TankLevel.empty;
  }
  return TankLevel.normal;
}

/// Whether moving from [previous] to [current] deserves a notification.
///
/// Only on *entering* full or empty. Staying full says nothing new, and the
/// return to normal is not something anyone needs to be woken for.
TankAlertKind? alertFor({
  required TankLevel? previous,
  required TankLevel current,
}) {
  if (current == previous) return null;
  return switch (current) {
    TankLevel.full => TankAlertKind.full,
    TankLevel.empty => TankAlertKind.empty,
    TankLevel.normal => null,
  };
}

/// Whether moving from [a] to [b] makes the remembered tank state
/// meaningless: another tank or sensor, another reading of its value, or
/// other thresholds. The next reading is then judged afresh, so a tank that
/// is already full is announced under the new settings.
bool judgesDifferently(TankConfig a, TankConfig b) =>
    a.sourceKey != b.sourceKey ||
    a.floatSensorId != b.floatSensorId ||
    a.valueKind != b.valueKind ||
    a.fullThreshold != b.fullThreshold ||
    a.emptyThreshold != b.emptyThreshold;

/// Checks a configuration before it is saved. Returns a message per field
/// that is wrong; empty means it can be saved.
Map<String, String> validateConfig(TankConfig c) {
  final errors = <String, String>{};

  if (c.deviceId == null) {
    errors['deviceId'] = 'Pilih perangkat yang memantau ground tank.';
  } else if (c.sensorId == null) {
    errors['sensorId'] = 'Pilih sensor ketinggian air pada perangkat itu.';
  }
  if (c.floatSensorId != null && c.floatSensorId == c.sensorId) {
    errors['floatSensorId'] =
        'Sensor pelampung harus berbeda dari sensor ketinggian.';
  }
  if (c.tankHeightCm <= 0) {
    errors['tankHeightCm'] = 'Tinggi tangki harus lebih dari 0.';
  }
  if (c.sensorToBottomCm < c.tankHeightCm) {
    errors['sensorToBottomCm'] =
        'Jarak sensor ke dasar tidak boleh lebih kecil dari tinggi air maksimum.';
  }
  if (c.capacityLiters <= 0) {
    errors['capacityLiters'] = 'Kapasitas harus lebih dari 0.';
  }
  if (c.fullThreshold > 100 || c.fullThreshold < 1) {
    errors['fullThreshold'] = 'Batas penuh harus di antara 1 dan 100.';
  }
  if (c.emptyThreshold < 0 || c.emptyThreshold > 99) {
    errors['emptyThreshold'] = 'Batas kosong harus di antara 0 dan 99.';
  }
  // Room for both hysteresis bands, or the two states could overlap.
  if (c.fullThreshold - c.emptyThreshold < 2 * hysteresisPercent + 1) {
    errors['fullThreshold'] =
        'Batas penuh harus minimal ${(2 * hysteresisPercent + 1).round()}% di atas batas kosong.';
  }
  if (c.pollSeconds < 2 || c.pollSeconds > 3600) {
    errors['pollSeconds'] = 'Interval antara 2 dan 3600 detik.';
  }
  return errors;
}

/// How the float switch and the level sensor disagree, if they do.
enum FloatMismatch {
  /// The float is lifted, yet the level is well below the full threshold.
  floatFullLevelLow,

  /// The level reads the brim, yet the float is down.
  levelFullFloatDown,
}

/// Points under the full threshold at which a lifted float stops being
/// explained by where it is mounted, and starts to look like a fault.
const double floatMismatchMargin = 10;

/// Null when the two sensors agree, or there is no float reading.
FloatMismatch? floatMismatch(TankReading reading, TankConfig config) {
  return switch (reading.floatFull) {
    true when reading.percent < config.fullThreshold - floatMismatchMargin =>
      FloatMismatch.floatFullLevelLow,
    false when reading.percent >= 99.5 => FloatMismatch.levelFullFloatDown,
    _ => null,
  };
}

/// Whether the newest reading is too old to be trusted as "now".
///
/// A device that lost power or Wi-Fi leaves its last row in the table, and
/// the dashboard would otherwise keep presenting it as the current level.
/// Allowed: three missed polling intervals, but never less than two minutes,
/// since sketches commonly send once a minute however fast the app polls.
bool isStale(DateTime measuredAt, {required int pollSeconds, DateTime? now}) {
  final allowed = Duration(seconds: pollSeconds * 3);
  final limit = allowed < const Duration(minutes: 2)
      ? const Duration(minutes: 2)
      : allowed;
  return (now ?? DateTime.now()).difference(measuredAt) > limit;
}

/// Which way the level is moving.
enum TrendDirection { filling, draining, steady }

class Trend {
  const Trend(this.direction, this.percentPerMinute);

  final TrendDirection direction;

  /// Signed: positive while filling.
  final double percentPerMinute;
}

/// The direction and speed of the last couple of minutes of readings.
///
/// Null until there is enough history to say — two readings at least ten
/// seconds apart — so the dashboard shows "menghitung…" rather than a guess.
Trend? trendOf(
  List<TankReading> history, {
  Duration window = const Duration(minutes: 2),
  double steadyBelow = 0.3,
}) {
  if (history.length < 2) return null;
  final last = history.last;
  final cutoff = last.measuredAt.subtract(window);
  final first = history.firstWhere(
    (r) => !r.measuredAt.isBefore(cutoff),
    orElse: () => history.first,
  );
  final seconds =
      last.measuredAt.difference(first.measuredAt).inMilliseconds / 1000;
  if (seconds < 10) return null;

  final rate = (last.percent - first.percent) / seconds * 60;
  final direction = rate.abs() < steadyBelow
      ? TrendDirection.steady
      : (rate > 0 ? TrendDirection.filling : TrendDirection.draining);
  return Trend(direction, rate);
}

/// Minutes until the tank reaches the threshold it is heading for, if it is
/// heading for one at the current rate.
double? minutesToThreshold(double percent, Trend trend, TankConfig config) {
  switch (trend.direction) {
    case TrendDirection.filling:
      if (percent >= config.fullThreshold) return null;
      return (config.fullThreshold - percent) / trend.percentPerMinute;
    case TrendDirection.draining:
      if (percent <= config.emptyThreshold) return null;
      return (percent - config.emptyThreshold) / -trend.percentPerMinute;
    case TrendDirection.steady:
      return null;
  }
}
