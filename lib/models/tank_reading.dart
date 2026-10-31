import 'package:flutter/foundation.dart';

/// One measurement of the tank, already converted to every unit the screen
/// shows.
@immutable
class TankReading {
  const TankReading({
    required this.percent,
    required this.levelCm,
    required this.volumeLiters,
    required this.measuredAt,
    this.distanceCm,
    this.floatFull,
    this.floatAt,
  });

  /// 0–100, clamped.
  final double percent;

  /// Water height above the tank floor.
  final double levelCm;

  final double volumeLiters;

  /// When the device took it — or when it arrived, if the device sent no time.
  final DateTime measuredAt;

  /// The raw ultrasonic distance, when the device reported one.
  final double? distanceCm;

  /// Whether the float switch is lifted, as of [floatAt]. Null when the tank
  /// has no float sensor or it has not reported yet.
  final bool? floatFull;
  final DateTime? floatAt;

  /// The same level with the float switch's latest state.
  TankReading withFloat(bool? full, DateTime? at) => TankReading(
    percent: percent,
    levelCm: levelCm,
    volumeLiters: volumeLiters,
    measuredAt: measuredAt,
    distanceCm: distanceCm,
    floatFull: full,
    floatAt: at,
  );
}
