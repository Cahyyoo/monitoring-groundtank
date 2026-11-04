import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/models/chart_range.dart';
import 'package:groundtank/models/tank_reading.dart';

TankReading _at(DateTime at) =>
    TankReading(percent: 50, levelCm: 100, volumeLiters: 2500, measuredAt: at);

void main() {
  final now = DateTime(2026, 11, 4, 14, 30);

  test('a preset is a window ending now', () {
    expect(LastPeriod.hours12.startAt(now), DateTime(2026, 11, 4, 2, 30));
    expect(LastPeriod.hours24.startAt(now), DateTime(2026, 11, 3, 14, 30));
    expect(LastPeriod.days7.startAt(now), DateTime(2026, 10, 28, 14, 30));
    expect(LastPeriod.days30.startAt(now), DateTime(2026, 10, 5, 14, 30));
    expect(LastPeriod.hours12.endAt(now), now);
  });

  test('a date span covers whole days', () {
    final span = DateSpan(DateTime(2026, 10, 1, 9), DateTime(2026, 10, 3, 9));
    expect(span.startAt(now), DateTime(2026, 10, 1));
    expect(span.endAt(now), DateTime(2026, 10, 4));
  });

  test('a date span that includes today ends now', () {
    final span = DateSpan(DateTime(2026, 11, 1), DateTime(2026, 11, 4));
    expect(span.endAt(now), now);
  });

  test('a date span crosses the end of a month', () {
    final span = DateSpan(DateTime(2026, 10, 30), DateTime(2026, 10, 31));
    expect(span.endAt(now), DateTime(2026, 11, 1));
  });

  group('chartSeries', () {
    final from = DateTime(2026, 11, 4, 2);
    final to = DateTime(2026, 11, 4, 14);
    final inside = _at(DateTime(2026, 11, 4, 8));

    test('leaves out points the moving window has passed', () {
      final series = chartSeries(
        [_at(DateTime(2026, 11, 4, 1)), inside, _at(DateTime(2026, 11, 4, 15))],
        null,
        from,
        to,
      );
      expect(series, [inside]);
    });

    test('ends on the current reading', () {
      final current = _at(DateTime(2026, 11, 4, 13));
      expect(chartSeries([inside], current, from, to), [inside, current]);
    });

    test('does not repeat a current reading older than the last point', () {
      final current = _at(DateTime(2026, 11, 4, 7));
      expect(chartSeries([inside], current, from, to), [inside]);
    });

    test('keeps the current reading out of a range it is not in', () {
      final current = _at(DateTime(2026, 11, 4, 15));
      expect(chartSeries([inside], current, from, to), [inside]);
    });
  });
}
