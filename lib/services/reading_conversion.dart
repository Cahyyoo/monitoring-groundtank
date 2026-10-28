import '../models/sensor.dart';
import '../models/tank_config.dart';
import '../models/tank_reading.dart';

/// Turning a `sensor_readings.value` into a [TankReading].
///
/// Pure, so every unit and edge case is pinned by a test rather than found on
/// a device.

final _distanceHint = RegExp(
  r'jarak|distance|ultrasonic|ultrasonik|sonar|sr04',
  caseSensitive: false,
);

/// What a sensor's value most likely measures, from its unit and name.
///
/// A percentage unit is unambiguous. A length unit is not: "cm" is used both
/// for the water height and for an ultrasonic sensor's distance to the
/// surface, so the sensor's name and data type decide, and the user can still
/// override the guess in Settings.
ValueKind inferValueKind(Sensor sensor) {
  final unit = sensor.unit?.trim().toLowerCase() ?? '';
  if (unit == '%' || unit == 'percent' || unit == 'persen') {
    return ValueKind.percent;
  }
  final hints = '${sensor.name} ${sensor.dataType ?? ''}';
  return _distanceHint.hasMatch(hints)
      ? ValueKind.distanceCm
      : ValueKind.levelCm;
}

/// Whether [sensor] could be measuring the water at all: its unit is a
/// percentage, a length, or not filled in. A device often carries other
/// sensors too (temperature, flow, voltage), and those are marked in the
/// picker rather than offered as if they were a level.
bool looksLikeLevelSensor(Sensor sensor) {
  final unit = sensor.unit?.trim().toLowerCase() ?? '';
  return const {
    '',
    '%',
    'percent',
    'persen',
    'cm',
    'mm',
    'm',
    'meter',
    'metre',
  }.contains(unit);
}

/// How many centimetres one unit of [unit] is. Unknown or missing units are
/// taken as centimetres, the unit almost every tank sketch reports.
double centimetresPer(String? unit) {
  switch (unit?.trim().toLowerCase()) {
    case 'mm':
      return 0.1;
    case 'm':
    case 'meter':
    case 'metre':
      return 100;
    default:
      return 1;
  }
}

/// The column is `text`, so a sketch may have written "75.3", "75,3" or
/// " 75 ". Null for anything that is not a finite number.
double? parseValue(String? text) {
  if (text == null) return null;
  final parsed = double.tryParse(text.trim().replaceAll(',', '.'));
  return parsed != null && parsed.isFinite ? parsed : null;
}

/// One reading, in every unit the dashboard shows, clamped to the tank.
TankReading readingFrom({
  required double value,
  required TankConfig config,
  required DateTime measuredAt,
}) {
  final height = config.tankHeightCm;
  final scale = centimetresPer(config.sensorUnit);
  final double percent;
  double? distance;

  switch (config.valueKind) {
    case ValueKind.percent:
      percent = value;
    case ValueKind.levelCm:
      percent = value * scale / height * 100;
    case ValueKind.distanceCm:
      distance = value * scale;
      percent = (config.sensorToBottomCm - distance) / height * 100;
  }

  final clamped = percent.clamp(0, 100).toDouble();
  return TankReading(
    percent: clamped,
    levelCm: height * clamped / 100,
    volumeLiters: config.capacityLiters * clamped / 100,
    measuredAt: measuredAt,
    distanceCm: distance,
  );
}
