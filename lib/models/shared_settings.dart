import 'package:flutter/foundation.dart';

import 'tank_config.dart';

/// The `tank_settings` row: the part of the configuration every phone
/// shares, so they all watch the same tank the same way.
///
/// Changed only through the `update_tank_settings` function with the admin
/// PIN (`supabase/setup.sql`); the table itself is read-only to the app.
@immutable
class SharedSettings {
  const SharedSettings({
    required this.deviceId,
    required this.levelSensorId,
    required this.valueKind,
    required this.tankHeightCm,
    required this.sensorToBottomCm,
    required this.capacityLiters,
    required this.fullThreshold,
    required this.emptyThreshold,
    this.deviceName,
    this.levelSensorName,
    this.levelSensorUnit,
    this.floatSensorId,
    this.floatSensorName,
    this.updatedAt,
  });

  final String deviceId;
  final String? deviceName;
  final String levelSensorId;
  final String? levelSensorName;
  final String? levelSensorUnit;
  final String? floatSensorId;
  final String? floatSensorName;
  final ValueKind valueKind;
  final double tankHeightCm;
  final double sensorToBottomCm;
  final double capacityLiters;
  final int fullThreshold;
  final int emptyThreshold;
  final DateTime? updatedAt;

  /// The row with the names of what it points at, embedded through each
  /// foreign key (the two sensor keys told apart by their column), so the
  /// phone can label the device and sensors without further queries.
  static const columns =
      'device_id, level_sensor_id, float_sensor_id, value_kind, '
      'tank_height_cm, sensor_to_bottom_cm, capacity_liters, '
      'full_threshold, empty_threshold, updated_at, '
      'device:devices(name), '
      'level_sensor:sensors!level_sensor_id(name, unit), '
      'float_sensor:sensors!float_sensor_id(name)';

  /// Null when the row names no device or level sensor (never saved, or what
  /// it pointed at was deleted) or carries a value that is not usable; the
  /// phone then keeps what it had rather than half of a configuration.
  static SharedSettings? fromRow(Map<String, dynamic> row) {
    final deviceId = _text(row['device_id']);
    final levelSensorId = _text(row['level_sensor_id']);
    final valueKind = ValueKind.values
        .where((k) => k.name == row['value_kind'])
        .firstOrNull;
    final height = _number(row['tank_height_cm']);
    final toBottom = _number(row['sensor_to_bottom_cm']);
    final capacity = _number(row['capacity_liters']);
    final full = _number(row['full_threshold']);
    final empty = _number(row['empty_threshold']);
    if (deviceId == null ||
        levelSensorId == null ||
        valueKind == null ||
        height == null ||
        toBottom == null ||
        capacity == null ||
        full == null ||
        empty == null) {
      return null;
    }
    final level = _embedded(row['level_sensor']);
    return SharedSettings(
      deviceId: deviceId,
      deviceName: _text(_embedded(row['device'])?['name']),
      levelSensorId: levelSensorId,
      levelSensorName: _text(level?['name']),
      levelSensorUnit: _text(level?['unit']),
      floatSensorId: _text(row['float_sensor_id']),
      floatSensorName: _text(_embedded(row['float_sensor'])?['name']),
      valueKind: valueKind,
      tankHeightCm: height,
      sensorToBottomCm: toBottom,
      capacityLiters: capacity,
      fullThreshold: full.round(),
      emptyThreshold: empty.round(),
      updatedAt: DateTime.tryParse('${row['updated_at']}')?.toLocal(),
    );
  }

  /// The shared part of [config]; null until it names a device and sensor.
  static SharedSettings? fromConfig(TankConfig config) {
    final deviceId = config.deviceId;
    final levelSensorId = config.sensorId;
    if (deviceId == null || levelSensorId == null) return null;
    return SharedSettings(
      deviceId: deviceId,
      deviceName: config.deviceName,
      levelSensorId: levelSensorId,
      levelSensorName: config.sensorName,
      levelSensorUnit: config.sensorUnit,
      floatSensorId: config.floatSensorId,
      floatSensorName: config.floatSensorName,
      valueKind: config.valueKind,
      tankHeightCm: config.tankHeightCm,
      sensorToBottomCm: config.sensorToBottomCm,
      capacityLiters: config.capacityLiters,
      fullThreshold: config.fullThreshold,
      emptyThreshold: config.emptyThreshold,
    );
  }

  /// [local] with the shared part replaced; this phone's own choices stay.
  ///
  /// A name the row could not embed is kept from [local] when it describes
  /// the same id, rather than dropped.
  TankConfig applyTo(TankConfig local) {
    String? keep(String? shared, String? id, String? localId, String? old) =>
        shared ?? (id == localId ? old : null);
    return local.copyWith(
      deviceId: () => deviceId,
      deviceName: () =>
          keep(deviceName, deviceId, local.deviceId, local.deviceName),
      sensorId: () => levelSensorId,
      sensorName: () => keep(
        levelSensorName,
        levelSensorId,
        local.sensorId,
        local.sensorName,
      ),
      sensorUnit: () => keep(
        levelSensorUnit,
        levelSensorId,
        local.sensorId,
        local.sensorUnit,
      ),
      floatSensorId: () => floatSensorId,
      floatSensorName: () => floatSensorId == null
          ? null
          : keep(
              floatSensorName,
              floatSensorId,
              local.floatSensorId,
              local.floatSensorName,
            ),
      valueKind: valueKind,
      tankHeightCm: tankHeightCm,
      sensorToBottomCm: sensorToBottomCm,
      capacityLiters: capacityLiters,
      fullThreshold: fullThreshold,
      emptyThreshold: emptyThreshold,
    );
  }

  /// The arguments of `update_tank_settings`.
  Map<String, Object?> rpcParams(String pin) => {
    'p_pin': pin,
    'p_device_id': deviceId,
    'p_level_sensor_id': levelSensorId,
    'p_float_sensor_id': floatSensorId,
    'p_value_kind': valueKind.name,
    'p_tank_height_cm': tankHeightCm,
    'p_sensor_to_bottom_cm': sensorToBottomCm,
    'p_capacity_liters': capacityLiters,
    'p_full_threshold': fullThreshold,
    'p_empty_threshold': emptyThreshold,
  };
}

/// PostgREST embeds a to-one relation as an object, or null.
Map<String, dynamic>? _embedded(Object? value) =>
    value is Map<String, dynamic> ? value : null;

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// `numeric` columns arrive as JSON numbers, or as strings when large.
double? _number(Object? value) {
  final number = switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };
  return number != null && number.isFinite ? number : null;
}
