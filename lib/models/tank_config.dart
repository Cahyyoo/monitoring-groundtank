import 'package:flutter/foundation.dart';

/// What a sensor's `value` measures.
enum ValueKind {
  /// Already a fill percentage, 0–100.
  percent,

  /// Water height above the tank floor.
  levelCm,

  /// Distance from an ultrasonic sensor's face down to the water surface.
  distanceCm,
}

/// Everything the user can set about the tank and how it is watched.
///
/// Readings always come from `sensor_readings` in Supabase, for the one
/// device and sensor chosen here.
///
/// Stored as one JSON document, so adding a field never needs a migration:
/// an older install simply reads the default for it.
@immutable
class TankConfig {
  const TankConfig({
    this.deviceId,
    this.deviceName,
    this.sensorId,
    this.sensorName,
    this.sensorUnit,
    this.valueKind = ValueKind.distanceCm,
    this.tankHeightCm = 200,
    this.sensorToBottomCm = 220,
    this.capacityLiters = 5000,
    this.fullThreshold = 90,
    this.emptyThreshold = 15,
    this.pollSeconds = 5,
    this.notificationsEnabled = true,
    this.backgroundEnabled = true,
  });

  /// `devices.id` of the tank's controller.
  final String? deviceId;

  /// Kept beside the id so the dashboard can name the device without a query.
  final String? deviceName;

  /// `sensors.id` of the level sensor on that device.
  final String? sensorId;
  final String? sensorName;

  /// `sensors.unit` at the time it was chosen; scales mm and m to cm.
  final String? sensorUnit;

  /// What the sensor's value means. Suggested from the unit when the sensor
  /// is picked, and changeable, since a unit of "cm" alone cannot say whether
  /// it is a water height or a distance to the surface.
  final ValueKind valueKind;

  /// Water height at 100%: from the tank floor to the highest water line.
  final double tankHeightCm;

  /// From an ultrasonic sensor's face down to the tank floor. Only used when
  /// [valueKind] is [ValueKind.distanceCm].
  final double sensorToBottomCm;

  /// Litres held at 100%.
  final double capacityLiters;

  /// Percent at or above which the tank counts as full.
  final int fullThreshold;

  /// Percent at or below which the tank counts as empty.
  final int emptyThreshold;

  /// How often the dashboard asks for a reading while it is on screen. With
  /// Realtime enabled this is only the safety net.
  final int pollSeconds;

  final bool notificationsEnabled;

  /// Whether Android keeps checking every ~15 minutes after the app closes.
  final bool backgroundEnabled;

  /// Whether a device and its level sensor have been chosen; until then
  /// there is nothing to read.
  bool get hasSensor => deviceId != null && sensorId != null;

  /// The data source a reading is tied to; another one is another tank.
  String get sourceKey => 'db:$deviceId:$sensorId';

  /// Nullable fields take a function so they can be cleared, not only set.
  TankConfig copyWith({
    String? Function()? deviceId,
    String? Function()? deviceName,
    String? Function()? sensorId,
    String? Function()? sensorName,
    String? Function()? sensorUnit,
    ValueKind? valueKind,
    double? tankHeightCm,
    double? sensorToBottomCm,
    double? capacityLiters,
    int? fullThreshold,
    int? emptyThreshold,
    int? pollSeconds,
    bool? notificationsEnabled,
    bool? backgroundEnabled,
  }) {
    return TankConfig(
      deviceId: deviceId != null ? deviceId() : this.deviceId,
      deviceName: deviceName != null ? deviceName() : this.deviceName,
      sensorId: sensorId != null ? sensorId() : this.sensorId,
      sensorName: sensorName != null ? sensorName() : this.sensorName,
      sensorUnit: sensorUnit != null ? sensorUnit() : this.sensorUnit,
      valueKind: valueKind ?? this.valueKind,
      tankHeightCm: tankHeightCm ?? this.tankHeightCm,
      sensorToBottomCm: sensorToBottomCm ?? this.sensorToBottomCm,
      capacityLiters: capacityLiters ?? this.capacityLiters,
      fullThreshold: fullThreshold ?? this.fullThreshold,
      emptyThreshold: emptyThreshold ?? this.emptyThreshold,
      pollSeconds: pollSeconds ?? this.pollSeconds,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      backgroundEnabled: backgroundEnabled ?? this.backgroundEnabled,
    );
  }

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'sensorId': sensorId,
    'sensorName': sensorName,
    'sensorUnit': sensorUnit,
    'valueKind': valueKind.name,
    'tankHeightCm': tankHeightCm,
    'sensorToBottomCm': sensorToBottomCm,
    'capacityLiters': capacityLiters,
    'fullThreshold': fullThreshold,
    'emptyThreshold': emptyThreshold,
    'pollSeconds': pollSeconds,
    'notificationsEnabled': notificationsEnabled,
    'backgroundEnabled': backgroundEnabled,
  };

  /// Tolerant on purpose: a missing or mistyped field falls back to its
  /// default instead of discarding the whole stored configuration. Keys of
  /// removed features (`sourceMode`, `endpointUrl`) are simply ignored.
  factory TankConfig.fromJson(Map<String, Object?> json) {
    const d = TankConfig();
    double number(String key, double fallback) =>
        (json[key] is num) ? (json[key] as num).toDouble() : fallback;
    int whole(String key, int fallback) =>
        (json[key] is num) ? (json[key] as num).round() : fallback;
    bool flag(String key, bool fallback) =>
        (json[key] is bool) ? json[key] as bool : fallback;
    String? text(String key) =>
        json[key] is String ? json[key] as String : null;
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((v) => v.name == json[key]).firstOrNull ?? fallback;

    return TankConfig(
      deviceId: text('deviceId'),
      deviceName: text('deviceName'),
      sensorId: text('sensorId'),
      sensorName: text('sensorName'),
      sensorUnit: text('sensorUnit'),
      valueKind: pick(ValueKind.values, 'valueKind', d.valueKind),
      tankHeightCm: number('tankHeightCm', d.tankHeightCm),
      sensorToBottomCm: number('sensorToBottomCm', d.sensorToBottomCm),
      capacityLiters: number('capacityLiters', d.capacityLiters),
      fullThreshold: whole('fullThreshold', d.fullThreshold),
      emptyThreshold: whole('emptyThreshold', d.emptyThreshold),
      pollSeconds: whole('pollSeconds', d.pollSeconds),
      notificationsEnabled: flag(
        'notificationsEnabled',
        d.notificationsEnabled,
      ),
      backgroundEnabled: flag('backgroundEnabled', d.backgroundEnabled),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TankConfig && mapEquals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}
