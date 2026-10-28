import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/models/device.dart';
import 'package:groundtank/models/sensor.dart';
import 'package:groundtank/models/sensor_reading.dart';
import 'package:groundtank/models/tank_config.dart';
import 'package:groundtank/services/reading_conversion.dart';

void main() {
  const tank = TankConfig(
    tankHeightCm: 200,
    sensorToBottomCm: 220,
    capacityLiters: 5000,
  );
  final at = DateTime(2026, 10, 28, 12);

  group('inferValueKind', () {
    Sensor sensor(String name, String? unit, [String? dataType]) =>
        Sensor(id: 's', name: name, unit: unit, dataType: dataType);

    test('a percentage unit means percent', () {
      expect(inferValueKind(sensor('Level', '%')), ValueKind.percent);
      expect(inferValueKind(sensor('Level', 'Persen')), ValueKind.percent);
    });

    test('a length named like an ultrasonic sensor means distance', () {
      expect(
        inferValueKind(sensor('Ultrasonic JSN-SR04T', 'cm')),
        ValueKind.distanceCm,
      );
      expect(inferValueKind(sensor('Jarak air', 'cm')), ValueKind.distanceCm);
      expect(
        inferValueKind(sensor('Sensor 1', 'mm', 'distance')),
        ValueKind.distanceCm,
      );
    });

    test('any other length means water height', () {
      expect(inferValueKind(sensor('Ketinggian air', 'cm')), ValueKind.levelCm);
      expect(inferValueKind(sensor('Water level', null)), ValueKind.levelCm);
    });

    test('only percentages, lengths and blank units look like a level', () {
      expect(looksLikeLevelSensor(sensor('Level', '%')), isTrue);
      expect(looksLikeLevelSensor(sensor('Ultrasonic', 'CM')), isTrue);
      expect(looksLikeLevelSensor(sensor('Level', null)), isTrue);
      expect(looksLikeLevelSensor(sensor('Suhu air DS18B20', '°C')), isFalse);
      expect(looksLikeLevelSensor(sensor('Flow', 'L/min')), isFalse);
    });
  });

  group('parseValue', () {
    test('reads the text column the way sketches write it', () {
      expect(parseValue('75.3'), 75.3);
      expect(parseValue(' 75,3 '), 75.3);
      expect(parseValue('120'), 120);
    });

    test('rejects what is not a finite number', () {
      expect(parseValue(null), isNull);
      expect(parseValue(''), isNull);
      expect(parseValue('ERR'), isNull);
      expect(parseValue('NaN'), isNull);
      expect(parseValue('Infinity'), isNull);
    });
  });

  group('readingFrom', () {
    test('percent', () {
      final r = readingFrom(
        value: 72.5,
        config: tank.copyWith(valueKind: ValueKind.percent),
        measuredAt: at,
      );
      expect(r.percent, 72.5);
      expect(r.levelCm, 145);
      expect(r.volumeLiters, 3625);
      expect(r.measuredAt, at);
    });

    test('water height in cm, mm and m', () {
      final level = tank.copyWith(valueKind: ValueKind.levelCm);
      expect(readingFrom(value: 50, config: level, measuredAt: at).percent, 25);
      expect(
        readingFrom(
          value: 500,
          config: level.copyWith(sensorUnit: () => 'mm'),
          measuredAt: at,
        ).percent,
        25,
      );
      expect(
        readingFrom(
          value: 0.5,
          config: level.copyWith(sensorUnit: () => 'm'),
          measuredAt: at,
        ).percent,
        25,
      );
    });

    test('ultrasonic distance: 220 cm to the floor, 70 cm to the surface', () {
      final r = readingFrom(
        value: 70,
        config: tank.copyWith(valueKind: ValueKind.distanceCm),
        measuredAt: at,
      );
      expect(r.levelCm, 150);
      expect(r.percent, 75);
      expect(r.distanceCm, 70);
    });

    test('clamps readings outside the tank', () {
      final distance = tank.copyWith(valueKind: ValueKind.distanceCm);
      // Closer than the brim (splash, foam) and further than the floor.
      expect(
        readingFrom(value: 5, config: distance, measuredAt: at).percent,
        100,
      );
      expect(
        readingFrom(value: 300, config: distance, measuredAt: at).percent,
        0,
      );
      final percent = tank.copyWith(valueKind: ValueKind.percent);
      expect(
        readingFrom(value: 130, config: percent, measuredAt: at).levelCm,
        200,
      );
    });
  });

  group('rows', () {
    test('SensorReading parses value text and a UTC timestamp', () {
      final r = SensorReading.fromRow({
        'value': '75,3',
        'timestamp': '2026-10-28T05:00:00+00:00',
      })!;
      expect(r.value, 75.3);
      expect(r.timestamp, DateTime.utc(2026, 10, 28, 5).toLocal());
    });

    test('SensorReading skips unusable rows', () {
      expect(
        SensorReading.fromRow({
          'value': 'ERR',
          'timestamp': '2026-10-28T05:00:00Z',
        }),
        isNull,
      );
      expect(SensorReading.fromRow({'value': '10'}), isNull);
    });

    test('Device reads its columns and tolerates blanks', () {
      final d = Device.fromRow({
        'id': 'd1',
        'name': '  ',
        'project': 'GroundTank',
        'ip_address': '',
        'status': true,
        'updated_at': '2026-10-28T05:00:00Z',
      });
      expect(d.name, 'Perangkat tanpa nama');
      expect(d.project, 'GroundTank');
      expect(d.ipAddress, isNull);
      expect(d.isActive, isTrue);
      expect(d.updatedAt, isNotNull);
    });

    test('Sensor reads a device_sensors row with its embedded sensor', () {
      final s = Sensor.fromDeviceSensorRow({
        'pin_config': 'TRIG=5, ECHO=18',
        'sensors': {
          'id': 's1',
          'name': 'JSN-SR04T',
          'unit': 'cm',
          'data_type': 'float',
        },
      })!;
      expect(s.id, 's1');
      expect(s.unit, 'cm');
      expect(s.pinConfig, 'TRIG=5, ECHO=18');
      expect(
        Sensor.fromDeviceSensorRow({'pin_config': 'x', 'sensors': null}),
        isNull,
      );
    });
  });

  test('a configuration saved with the removed HTTP source loads as demo', () {
    final config = TankConfig.fromJson({
      'sourceMode': 'http',
      'endpointUrl': 'http://192.168.1.50/api/level',
      'fullThreshold': 85,
    });
    expect(config.sourceMode, SourceMode.demo);
    expect(config.fullThreshold, 85);
  });
}
