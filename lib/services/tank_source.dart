import 'dart:math' as math;

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
  /// [repository] is required for [SourceMode.database]; without one (the
  /// build has no Supabase keys) every fetch explains that instead.
  static TankSource forConfig(TankConfig config, {TankRepository? repository}) {
    return switch (config.sourceMode) {
      SourceMode.demo => DemoTankSource(config),
      SourceMode.database when repository != null => DatabaseTankSource(
        repository,
        config,
      ),
      SourceMode.database => const _UnavailableSource(
        'Supabase belum dikonfigurasi pada build ini (env.json).',
      ),
    };
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

/// A simulated tank that fills and drains on a [period] cycle.
///
/// A function of the wall clock rather than of internal state, so the
/// dashboard and the background check — two isolates — see the same tank,
/// and a demo left running visits both full and empty within one cycle.
class DemoTankSource extends TankSource {
  DemoTankSource(
    this.config, {
    this.period = const Duration(minutes: 6),
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 250),
  }) : _clock = clock ?? DateTime.now;

  final TankConfig config;
  final Duration period;
  final Duration latency;
  final DateTime Function() _clock;

  /// The level at [at], before clamping. Overshoots 0 and 100 a little so the
  /// tank rests at each end for a moment, as a real one does while a pump or
  /// a float valve catches up.
  double percentAt(DateTime at) {
    final t = at.millisecondsSinceEpoch / period.inMilliseconds;
    final wave = 50 - 56 * math.cos(2 * math.pi * t);
    final ripple = 0.6 * math.sin(2 * math.pi * t * 37);
    return (wave + ripple).clamp(0, 100).toDouble();
  }

  TankReading _readingAt(DateTime at) {
    final percent = percentAt(at);
    final level = config.tankHeightCm * percent / 100;
    return TankReading(
      percent: percent,
      levelCm: level,
      volumeLiters: config.capacityLiters * percent / 100,
      measuredAt: at,
      distanceCm: config.sensorToBottomCm - level,
    );
  }

  @override
  Future<TankReading> fetch() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _readingAt(_clock());
  }

  @override
  Future<List<TankReading>> recent(Duration window) async {
    final now = _clock();
    final step = Duration(seconds: config.pollSeconds.clamp(2, 3600));
    final count = (window.inSeconds / step.inSeconds).floor().clamp(0, 120);
    return [for (var i = count; i > 0; i--) _readingAt(now.subtract(step * i))];
  }
}

class _UnavailableSource extends TankSource {
  const _UnavailableSource(this.message);

  final String message;

  @override
  Future<TankReading> fetch() async => throw TankSourceException(message);
}
