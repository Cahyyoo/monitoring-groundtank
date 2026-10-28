import 'package:flutter/foundation.dart';

/// A row of `sensors`, as attached to one device through `device_sensors`.
@immutable
class Sensor {
  const Sensor({
    required this.id,
    required this.name,
    this.unit,
    this.dataType,
    this.pinConfig,
  });

  final String id;
  final String name;

  /// Decides what `sensor_readings.value` means; see `inferValueKind`.
  final String? unit;

  final String? dataType;

  /// From `device_sensors`, e.g. "TRIG=5, ECHO=18".
  final String? pinConfig;

  /// The `device_sensors` select that embeds each sensor through its
  /// foreign key, in one request.
  static const deviceSensorColumns =
      'pin_config, sensors(id, name, unit, data_type)';

  /// Reads one `device_sensors` row with its embedded `sensors` object.
  /// Null when the embed is missing (a dangling foreign key, or RLS hiding
  /// the sensor), so one bad link cannot break the list.
  static Sensor? fromDeviceSensorRow(Map<String, dynamic> row) {
    final sensor = row['sensors'];
    if (sensor is! Map<String, dynamic> || sensor['id'] is! String) return null;
    return Sensor(
      id: sensor['id'] as String,
      name: _text(sensor['name']) ?? 'Sensor tanpa nama',
      unit: _text(sensor['unit']),
      dataType: _text(sensor['data_type']),
      pinConfig: _text(row['pin_config']),
    );
  }
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
