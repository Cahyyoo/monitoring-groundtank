import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/models/tank_config.dart';
import 'package:groundtank/models/tank_level.dart';
import 'package:groundtank/models/tank_reading.dart';
import 'package:groundtank/services/tank_rules.dart';

void main() {
  const config = TankConfig(fullThreshold: 90, emptyThreshold: 15);

  group('classifyLevel', () {
    test('uses the thresholds inclusively', () {
      expect(classifyLevel(90, config), TankLevel.full);
      expect(classifyLevel(89.9, config), TankLevel.normal);
      expect(classifyLevel(15, config), TankLevel.empty);
      expect(classifyLevel(15.1, config), TankLevel.normal);
    });

    test('holds full until the level falls past the hysteresis band', () {
      expect(
        classifyLevel(88, config, previous: TankLevel.full),
        TankLevel.full,
      );
      expect(
        classifyLevel(87.5, config, previous: TankLevel.full),
        TankLevel.full,
      );
      expect(
        classifyLevel(87, config, previous: TankLevel.full),
        TankLevel.normal,
      );
    });

    test('holds empty until the level rises past the hysteresis band', () {
      expect(
        classifyLevel(17, config, previous: TankLevel.empty),
        TankLevel.empty,
      );
      expect(
        classifyLevel(18, config, previous: TankLevel.empty),
        TankLevel.normal,
      );
    });

    test('does not borrow hysteresis from the other end', () {
      expect(
        classifyLevel(88, config, previous: TankLevel.empty),
        TankLevel.normal,
      );
      expect(
        classifyLevel(17, config, previous: TankLevel.full),
        TankLevel.normal,
      );
    });
  });

  group('alertFor', () {
    test('alerts on entering full or empty', () {
      expect(
        alertFor(previous: TankLevel.normal, current: TankLevel.full),
        TankAlertKind.full,
      );
      expect(
        alertFor(previous: TankLevel.normal, current: TankLevel.empty),
        TankAlertKind.empty,
      );
      expect(
        alertFor(previous: null, current: TankLevel.full),
        TankAlertKind.full,
      );
      expect(
        alertFor(previous: TankLevel.full, current: TankLevel.empty),
        TankAlertKind.empty,
      );
    });

    test('stays quiet while nothing changes, and on returning to normal', () {
      expect(
        alertFor(previous: TankLevel.full, current: TankLevel.full),
        isNull,
      );
      expect(
        alertFor(previous: TankLevel.full, current: TankLevel.normal),
        isNull,
      );
      expect(alertFor(previous: null, current: TankLevel.normal), isNull);
    });

    test('a sloshing tank near the brim notifies once', () {
      var previous = TankLevel.normal;
      var alerts = 0;
      for (final p in [89.0, 90.5, 89.2, 90.1, 88.4, 91.0, 89.0]) {
        final level = classifyLevel(p, config, previous: previous);
        if (alertFor(previous: previous, current: level) != null) alerts++;
        previous = level;
      }
      expect(alerts, 1);
    });
  });

  group('validateConfig', () {
    test('needs a device and then a sensor', () {
      const defaults = TankConfig();
      expect(validateConfig(defaults), contains('deviceId'));
      expect(
        validateConfig(defaults.copyWith(deviceId: () => 'device-1')),
        contains('sensorId'),
      );
      expect(
        validateConfig(
          defaults.copyWith(
            deviceId: () => 'device-1',
            sensorId: () => 'sensor-1',
          ),
        ),
        isEmpty,
      );
    });

    test('rejects impossible dimensions and overlapping thresholds', () {
      expect(
        validateConfig(const TankConfig(tankHeightCm: 0)),
        contains('tankHeightCm'),
      );
      expect(
        validateConfig(
          const TankConfig(tankHeightCm: 200, sensorToBottomCm: 150),
        ),
        contains('sensorToBottomCm'),
      );
      expect(
        validateConfig(const TankConfig(fullThreshold: 20, emptyThreshold: 18)),
        contains('fullThreshold'),
      );
      expect(
        validateConfig(const TankConfig(pollSeconds: 1)),
        contains('pollSeconds'),
      );
    });
  });

  group('isStale', () {
    final now = DateTime(2026, 10, 28, 12);

    test('allows at least two minutes, even when polling fast', () {
      final ago = now.subtract(const Duration(seconds: 100));
      expect(isStale(ago, pollSeconds: 5, now: now), isFalse);
      expect(
        isStale(
          now.subtract(const Duration(minutes: 3)),
          pollSeconds: 5,
          now: now,
        ),
        isTrue,
      );
    });

    test('allows three missed intervals when polling slowly', () {
      final ago = now.subtract(const Duration(minutes: 25));
      expect(isStale(ago, pollSeconds: 600, now: now), isFalse);
      expect(
        isStale(
          now.subtract(const Duration(minutes: 31)),
          pollSeconds: 600,
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('trendOf', () {
    TankReading at(int second, double percent) => TankReading(
      percent: percent,
      levelCm: 0,
      volumeLiters: 0,
      measuredAt: DateTime(2026, 1, 1, 12, 0, second),
    );

    test('waits for enough history', () {
      expect(trendOf([at(0, 50)]), isNull);
      expect(trendOf([at(0, 50), at(5, 51)]), isNull);
    });

    test('measures the rate per minute', () {
      final trend = trendOf([at(0, 50), at(15, 51), at(30, 52)])!;
      expect(trend.direction, TrendDirection.filling);
      expect(trend.percentPerMinute, closeTo(4, 1e-9));
    });

    test('calls a tiny change steady', () {
      final trend = trendOf([at(0, 50), at(30, 50.1)])!;
      expect(trend.direction, TrendDirection.steady);
    });

    test('estimates time to the threshold it is heading for', () {
      const draining = Trend(TrendDirection.draining, -2);
      expect(minutesToThreshold(35, draining, config), 10);
      const filling = Trend(TrendDirection.filling, 5);
      expect(minutesToThreshold(80, filling, config), 2);
      expect(minutesToThreshold(95, filling, config), isNull);
    });
  });
}
