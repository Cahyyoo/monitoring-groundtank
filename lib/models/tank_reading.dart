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
}
