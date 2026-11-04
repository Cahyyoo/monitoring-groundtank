import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chart_range.dart';
import '../models/tank_reading.dart';
import 'config_provider.dart';
import 'monitor_provider.dart';

/// The range chosen above the chart. Starts at 12 hours on every launch.
final chartRangeProvider = StateProvider<ChartRange>(
  (ref) => LastPeriod.hours12,
);

/// The chart's averaged points for the chosen range, oldest first.
///
/// Fetched again once a new point is due while the range is still running.
/// In the background that waits: `MonitorScope` refreshes it on return.
final chartReadingsProvider = FutureProvider<List<TankReading>>((ref) async {
  final range = ref.watch(chartRangeProvider);
  final config = ref.watch(configProvider);
  final source = ref.watch(tankSourceProvider);
  if (!config.hasSensor) return const [];

  final now = DateTime.now();
  final start = range.startAt(now);
  final end = range.endAt(now);

  if (!end.isBefore(now)) {
    final perPoint = end.difference(start) ~/ ChartRange.maxPoints;
    const atLeast = Duration(minutes: 1);
    final timer = Timer(perPoint < atLeast ? atLeast : perPoint, () {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        ref.invalidateSelf();
      }
    });
    ref.onDispose(timer.cancel);
  }

  return source.chart(start, end);
});
