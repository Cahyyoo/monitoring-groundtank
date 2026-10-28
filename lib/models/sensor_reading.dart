import 'package:flutter/foundation.dart';

import '../services/reading_conversion.dart';

/// A row of `sensor_readings`, its text `value` already parsed.
@immutable
class SensorReading {
  const SensorReading({required this.value, required this.timestamp});

  final double value;
  final DateTime timestamp;

  static const columns = 'value, timestamp';

  /// Null when the value is not a number — a sketch's error string, say — or
  /// the timestamp is missing, so one bad row is skipped rather than failing
  /// a whole history.
  static SensorReading? fromRow(Map<String, dynamic> row) {
    final value = parseValue(row['value']?.toString());
    final raw = row['timestamp'];
    final timestamp = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    if (value == null || timestamp == null) return null;
    return SensorReading(value: value, timestamp: timestamp);
  }
}
