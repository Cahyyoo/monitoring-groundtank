import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/models/tank_config.dart';
import 'package:groundtank/models/tank_level.dart';
import 'package:groundtank/models/tank_reading.dart';
import 'package:groundtank/providers/config_provider.dart';
import 'package:groundtank/providers/monitor_provider.dart';
import 'package:groundtank/services/tank_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

TankReading _reading(double percent, DateTime at) => TankReading(
  percent: percent,
  levelCm: percent * 2,
  volumeLiters: percent * 50,
  measuredAt: at,
);

const _withSensor = TankConfig(deviceId: 'device-1', sensorId: 'sensor-1');

ProviderContainer _container(
  TankSource source, {
  TankConfig config = _withSensor,
}) {
  final container = ProviderContainer(
    overrides: [
      configProvider.overrideWith((ref) => ConfigNotifier(config)),
      tankSourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// A database-like source: some history, a latest row, and pushed inserts.
class _PushSource extends TankSource {
  _PushSource(this.history);

  final List<TankReading> history;
  final pushes = StreamController<TankReading>.broadcast();
  int fetches = 0;

  @override
  Future<TankReading> fetch() async {
    fetches++;
    return history.last;
  }

  @override
  Future<List<TankReading>> recent(Duration window) async => history;

  @override
  Stream<TankReading>? watch() => pushes.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fills the chart from history, then follows pushed readings', () async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final source = _PushSource([
      _reading(40, now.subtract(const Duration(seconds: 20))),
      _reading(45, now.subtract(const Duration(seconds: 10))),
    ]);
    final container = _container(source);

    container.read(monitorProvider);
    await pumpEventQueue();

    var state = container.read(monitorProvider);
    expect(state.history.map((r) => r.percent), [40, 45]);
    expect(state.level, TankLevel.normal);
    expect(state.isOutdated, isFalse);

    // A Realtime insert arrives: it is judged and appended once, and the poll
    // that returns the same row afterwards does not append it again.
    final pushed = _reading(95, now);
    source.history.add(pushed);
    source.pushes.add(pushed);
    await pumpEventQueue();
    await container.read(monitorProvider.notifier).refresh();

    state = container.read(monitorProvider);
    expect(state.history.map((r) => r.percent), [40, 45, 95]);
    expect(state.level, TankLevel.full);
    expect(state.lastAlert?.kind, TankAlertKind.full);
  });

  test('flags a device whose newest row is old', () async {
    SharedPreferences.setMockInitialValues({});
    final source = _PushSource([
      _reading(50, DateTime.now().subtract(const Duration(minutes: 30))),
    ]);
    final container = _container(source);

    container.read(monitorProvider);
    await pumpEventQueue();

    final state = container.read(monitorProvider);
    expect(state.reading?.percent, 50);
    expect(state.isOutdated, isTrue);
  });

  test('reads nothing until a sensor is chosen', () async {
    SharedPreferences.setMockInitialValues({});
    final source = _PushSource([_reading(50, DateTime.now())]);
    final container = _container(source, config: const TankConfig());

    container.read(monitorProvider);
    await pumpEventQueue();
    await container.read(monitorProvider.notifier).refresh();

    final state = container.read(monitorProvider);
    expect(source.fetches, 0);
    expect(state.reading, isNull);
    expect(state.error, isNull);
    expect(state.isFetching, isFalse);
  });
}
