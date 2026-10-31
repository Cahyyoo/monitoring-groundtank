import 'dart:async';

import '../models/sensor_reading.dart';
import '../models/tank_config.dart';
import '../models/tank_reading.dart';
import 'reading_conversion.dart';
import 'tank_repository.dart';

/// A failed reading, worded for the person looking at the dashboard.
class TankSourceException implements Exception {
  const TankSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Somewhere readings of the tank come from.
abstract class TankSource {
  const TankSource();

  /// The newest reading.
  Future<TankReading> fetch();

  /// Readings from the last [window], oldest first, to fill the chart when
  /// the dashboard opens instead of starting it empty.
  Future<List<TankReading>> recent(Duration window) async => const [];

  /// New readings as they happen, for a source that can push them. Null
  /// when the source can only be polled.
  Stream<TankReading>? watch() => null;

  /// The source a configuration asks for. Used by both the dashboard and the
  /// background check, so the two never disagree about where data lives.
  ///
  /// Without a [repository] (the build has no Supabase keys) every fetch
  /// explains that instead.
  static TankSource forConfig(TankConfig config, {TankRepository? repository}) {
    if (repository == null) {
      return const _UnavailableSource(
        'Supabase belum dikonfigurasi pada build ini (env.json).',
      );
    }
    return DatabaseTankSource(repository, config);
  }
}

/// `sensor_readings` for the configured device and sensor, with the float
/// switch's latest state attached when the tank has one.
///
/// Remembers the last level and float rows it saw, so a float change pushed
/// on its own can be shown against the current level. One instance serves
/// one configuration; a new configuration builds a new source.
class DatabaseTankSource extends TankSource {
  DatabaseTankSource(this._repository, this.config);

  final TankRepository _repository;
  final TankConfig config;

  SensorReading? _lastLevel;
  SensorReading? _lastFloat;

  (String, String) get _ids {
    final device = config.deviceId;
    final sensor = config.sensorId;
    if (device == null || sensor == null) {
      throw const TankSourceException(
        'Perangkat dan sensor belum dipilih. Atur di tab Pengaturan.',
      );
    }
    return (device, sensor);
  }

  /// The float's newest row. A failure keeps the last one known: the level
  /// is still worth showing without it.
  Future<SensorReading?> _latestFloat(String device) async {
    final floatId = config.floatSensorId;
    if (floatId == null) return null;
    try {
      return _lastFloat = await _repository.fetchLatest(device, floatId);
    } on TankSourceException {
      return _lastFloat;
    }
  }

  TankReading _compose(SensorReading level, SensorReading? float) {
    final reading = readingFrom(
      value: level.value,
      config: config,
      measuredAt: level.timestamp,
    );
    if (float == null) return reading;
    return reading.withFloat(floatIsFull(float.value), float.timestamp);
  }

  @override
  Future<TankReading> fetch() async {
    final (device, sensor) = _ids;
    final float = _latestFloat(device);
    final row = await _repository.fetchLatest(device, sensor);
    if (row == null) {
      throw const TankSourceException(
        'Sensor ini belum mengirim data apa pun.',
      );
    }
    _lastLevel = row;
    return _compose(row, await float);
  }

  /// Only the newest reading carries the float: it is the one the state is
  /// judged on, and a stale float on older points would mean nothing.
  @override
  Future<List<TankReading>> recent(Duration window) async {
    final (device, sensor) = _ids;
    final float = _latestFloat(device);
    final rows = await _repository.fetchSince(
      device,
      sensor,
      DateTime.now().subtract(window),
    );
    if (rows.isEmpty) return const [];
    _lastLevel = rows.last;
    final latestFloat = await float;
    return [
      for (var i = 0; i < rows.length; i++)
        i == rows.length - 1
            ? _compose(rows[i], latestFloat)
            : _compose(rows[i], null),
    ];
  }

  @override
  Stream<TankReading>? watch() {
    final device = config.deviceId;
    final sensor = config.sensorId;
    if (device == null || sensor == null) return null;
    final floatId = config.floatSensorId;

    final levels = _repository.watchInserts(device, sensor);
    if (floatId == null) {
      return levels.map((row) => _compose(_lastLevel = row, null));
    }

    // Two channels, one stream: a new level carries the float as last seen,
    // and a new float re-states the current level with it.
    final floats = _repository.watchInserts(device, floatId);
    final subscriptions = <StreamSubscription<SensorReading>>[];
    late final StreamController<TankReading> controller;
    controller = StreamController<TankReading>(
      onListen: () {
        subscriptions
          ..add(
            levels.listen(
              (row) => controller.add(_compose(_lastLevel = row, _lastFloat)),
              onError: controller.addError,
            ),
          )
          ..add(
            floats.listen((row) {
              _lastFloat = row;
              final level = _lastLevel;
              if (level != null) controller.add(_compose(level, row));
            }, onError: controller.addError),
          );
      },
      onCancel: () async {
        await Future.wait([for (final s in subscriptions) s.cancel()]);
        subscriptions.clear();
      },
    );
    return controller.stream;
  }
}

class _UnavailableSource extends TankSource {
  const _UnavailableSource(this.message);

  final String message;

  @override
  Future<TankReading> fetch() async => throw TankSourceException(message);
}
