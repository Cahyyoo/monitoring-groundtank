import 'package:flutter/foundation.dart';

import 'tank_reading.dart';

/// The stretch of time the level chart shows.
@immutable
sealed class ChartRange {
  const ChartRange();

  /// How many points the server is asked to average a range into; enough for
  /// the width of a phone, and well inside what one request may return.
  static const maxPoints = 240;

  DateTime startAt(DateTime now);
  DateTime endAt(DateTime now);
}

/// A window ending now, which moves along with the clock.
final class LastPeriod extends ChartRange {
  const LastPeriod(this.label, this.duration);

  final String label;
  final Duration duration;

  static const hours12 = LastPeriod('12 jam', Duration(hours: 12));
  static const hours24 = LastPeriod('24 jam', Duration(hours: 24));
  static const days7 = LastPeriod('7 hari', Duration(days: 7));
  static const days30 = LastPeriod('1 bulan', Duration(days: 30));

  static const all = [hours12, hours24, days7, days30];

  @override
  DateTime startAt(DateTime now) => now.subtract(duration);

  @override
  DateTime endAt(DateTime now) => now;
}

/// Whole days, from the first one's midnight to the end of the last.
final class DateSpan extends ChartRange {
  const DateSpan(this.firstDay, this.lastDay);

  final DateTime firstDay;
  final DateTime lastDay;

  @override
  DateTime startAt(DateTime now) =>
      DateTime(firstDay.year, firstDay.month, firstDay.day);

  /// Never past [now], so a span that includes today ends at the present.
  @override
  DateTime endAt(DateTime now) {
    final dayAfter = DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
    return dayAfter.isAfter(now) ? now : dayAfter;
  }
}

/// What the chart draws between [from] and [to]: the averaged [points], with
/// [current] after them so the line ends on the level shown above it.
List<TankReading> chartSeries(
  List<TankReading> points,
  TankReading? current,
  DateTime from,
  DateTime to,
) {
  bool inside(TankReading r) =>
      !r.measuredAt.isBefore(from) && !r.measuredAt.isAfter(to);

  final series = points.where(inside).toList();
  if (current != null &&
      inside(current) &&
      (series.isEmpty || current.measuredAt.isAfter(series.last.measuredAt))) {
    series.add(current);
  }
  return series;
}
