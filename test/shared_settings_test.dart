import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/models/shared_settings.dart';
import 'package:groundtank/models/tank_config.dart';

Map<String, dynamic> _row({Map<String, dynamic> overrides = const {}}) => {
  'device_id': 'device-1',
  'level_sensor_id': 'sensor-1',
  'float_sensor_id': 'float-1',
  'value_kind': 'distanceCm',
  'tank_height_cm': 180,
  'sensor_to_bottom_cm': '205.5',
  'capacity_liters': 1000,
  'full_threshold': 85,
  'empty_threshold': 20,
  'updated_at': '2026-10-31T06:00:00+00:00',
  'device': {'name': 'ESP32 Ground Tank'},
  'level_sensor': {'name': 'Ultrasonic', 'unit': 'cm'},
  'float_sensor': {'name': 'Float switch'},
  ...overrides,
};

void main() {
  test('reads a row with its embedded names', () {
    final s = SharedSettings.fromRow(_row())!;
    expect(s.deviceName, 'ESP32 Ground Tank');
    expect(s.levelSensorUnit, 'cm');
    expect(s.floatSensorName, 'Float switch');
    expect(s.valueKind, ValueKind.distanceCm);
    // numeric may come back as a string.
    expect(s.sensorToBottomCm, 205.5);
    expect(s.fullThreshold, 85);
    expect(s.updatedAt, DateTime.utc(2026, 10, 31, 6).toLocal());
  });

  test('rejects a row that names no tank or carries a bad value', () {
    expect(
      SharedSettings.fromRow(_row(overrides: {'device_id': null})),
      isNull,
    );
    expect(
      SharedSettings.fromRow(_row(overrides: {'value_kind': 'liters'})),
      isNull,
    );
    expect(
      SharedSettings.fromRow(_row(overrides: {'tank_height_cm': 'abc'})),
      isNull,
    );
  });

  test('replaces the shared part and keeps this phone\'s choices', () {
    const local = TankConfig(
      deviceId: 'old-device',
      deviceName: 'Old',
      sensorId: 'old-sensor',
      pollSeconds: 30,
      notificationsEnabled: false,
      backgroundEnabled: false,
    );
    final merged = SharedSettings.fromRow(_row())!.applyTo(local);

    expect(merged.deviceId, 'device-1');
    expect(merged.deviceName, 'ESP32 Ground Tank');
    expect(merged.floatSensorId, 'float-1');
    expect(merged.tankHeightCm, 180);
    expect(merged.fullThreshold, 85);
    expect(merged.pollSeconds, 30);
    expect(merged.notificationsEnabled, isFalse);
    expect(merged.backgroundEnabled, isFalse);
  });

  test('keeps a name the row could not embed, for the same id only', () {
    const local = TankConfig(
      deviceId: 'device-1',
      deviceName: 'Known name',
      sensorId: 'sensor-9',
      sensorName: 'Other sensor',
    );
    final merged = SharedSettings.fromRow(
      _row(overrides: {'device': null, 'level_sensor': null}),
    )!.applyTo(local);
    expect(merged.deviceName, 'Known name');
    expect(merged.sensorName, isNull);
  });

  test('round-trips a configuration into the RPC arguments', () {
    expect(SharedSettings.fromConfig(const TankConfig()), isNull);
    const config = TankConfig(
      deviceId: 'device-1',
      sensorId: 'sensor-1',
      valueKind: ValueKind.levelCm,
      tankHeightCm: 150,
    );
    final params = SharedSettings.fromConfig(config)!.rpcParams('123456');
    expect(params['p_pin'], '123456');
    expect(params['p_level_sensor_id'], 'sensor-1');
    expect(params['p_float_sensor_id'], isNull);
    expect(params['p_value_kind'], 'levelCm');
    expect(params['p_tank_height_cm'], 150);
  });
}
