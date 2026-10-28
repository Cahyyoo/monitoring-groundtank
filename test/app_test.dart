import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/main.dart';
import 'package:groundtank/models/tank_level.dart';
import 'package:groundtank/models/tank_reading.dart';
import 'package:groundtank/providers/monitor_provider.dart';
import 'package:groundtank/providers/alerts_provider.dart';
import 'package:groundtank/services/tank_source.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tank whose level the test sets by hand.
class _FakeSource extends TankSource {
  double percent = 50;

  @override
  Future<TankReading> fetch() async => TankReading(
    percent: percent,
    levelCm: percent * 2,
    volumeLiters: percent * 50,
    measuredAt: DateTime.now(),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  testWidgets('dashboard shows the level and logs a full tank once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final source = _FakeSource();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tankSourceProvider.overrideWithValue(source)],
        child: const GroundTankApp(),
      ),
    );
    // Not pumpAndSettle: the water's surface never stops moving.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('GroundTank'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);

    // The tank fills: one alert, then nothing more while it stays full.
    source.percent = 95;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GroundTankApp)),
    );
    container.read(monitorProvider.notifier).refresh();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('95%'), findsOneWidget);
    expect(find.text('Penuh'), findsWidgets);

    container.read(monitorProvider.notifier).refresh();
    await tester.pump(const Duration(milliseconds: 100));
    final alerts = container.read(alertsProvider).entries;
    expect(alerts, hasLength(1));
    expect(alerts.single.kind, TankAlertKind.full);

    // Let the toast's timer run out, then tear the tree down so the polling
    // timer and the wave stop with it.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });
}
