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

/// `sensor_readings` for the configured device and sensor.
class DatabaseTankSource extends TankSource {
  const DatabaseTankSource(this._repository, this.config);

  final TankRepository _repository;
  final TankConfig config;

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

  @override
  Future<TankReading> fetch() async {
    final (device, sensor) = _ids;
    final row = await _repository.fetchLatest(device, sensor);
    if (row == null) {
      throw const TankSourceException(
        'Sensor ini belum mengirim data apa pun.',
      );
    }
    return readingFrom(
      value: row.value,
      config: config,
      measuredAt: row.timestamp,
    );
  }

  @override
  Future<List<TankReading>> recent(Duration window) async {
    final (device, sensor) = _ids;
    final rows = await _repository.fetchSince(
      device,
      sensor,
      DateTime.now().subtract(window),
    );
    return [
      for (final row in rows)
        readingFrom(
          value: row.value,
          config: config,
          measuredAt: row.timestamp,
        ),
    ];
  }

  @override
  Stream<TankReading>? watch() {
    final device = config.deviceId;
    final sensor = config.sensorId;
    if (device == null || sensor == null) return null;
    return _repository
        .watchInserts(device, sensor)
        .map(
          (row) => readingFrom(
            value: row.value,
            config: config,
            measuredAt: row.timestamp,
          ),
        );
  }
}

class _UnavailableSource extends TankSource {
  const _UnavailableSource(this.message);

  final String message;

  @override
  Future<TankReading> fetch() async => throw TankSourceException(message);
}
