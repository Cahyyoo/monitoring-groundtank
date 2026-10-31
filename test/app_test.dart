import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/main.dart';
import 'package:groundtank/models/shared_settings.dart';
import 'package:groundtank/models/tank_config.dart';
import 'package:groundtank/models/tank_level.dart';
import 'package:groundtank/models/tank_reading.dart';
import 'package:groundtank/providers/alerts_provider.dart';
import 'package:groundtank/providers/config_provider.dart';
import 'package:groundtank/providers/database_providers.dart';
import 'package:groundtank/providers/monitor_provider.dart';
import 'package:groundtank/services/tank_repository.dart';
import 'package:groundtank/services/tank_source.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

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

/// A repository whose admin PIN is 123456, and that never touches a network.
class _FakeRepository extends TankRepository {
  _FakeRepository()
    : super(
        SupabaseClient(
          'http://localhost:54321',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final tried = <String>[];

  @override
  Future<SharedSettings?> fetchSharedSettings() async => null;

  @override
  Stream<void> watchSharedSettings() => const Stream.empty();

  @override
  Future<void> verifySettingsPin(String pin) async {
    tried.add(pin);
    if (pin != '123456') throw const TankSourceException('PIN salah.');
  }
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
        overrides: [
          configProvider.overrideWith(
            (ref) => ConfigNotifier(
              const TankConfig(
                deviceId: 'device-1',
                deviceName: 'ESP32 Ground Tank',
                sensorId: 'sensor-1',
              ),
            ),
          ),
          tankSourceProvider.overrideWithValue(source),
        ],
        child: const GroundTankApp(),
      ),
    );
    // Not pumpAndSettle: the water's surface never stops moving.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('GroundTank'), findsOneWidget);
    expect(find.text('ESP32 Ground Tank'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
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

  testWidgets('dashboard asks for a sensor before one is chosen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: GroundTankApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Sensor belum dipilih'), findsOneWidget);
    expect(find.text('Belum diatur'), findsOneWidget);
    expect(find.text('--'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tank settings stay locked until the server accepts the PIN', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeRepository();
    // Tall enough that the whole Settings list is built, not just its top.
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWith(
            (ref) => ConfigNotifier(
              const TankConfig(deviceId: 'device-1', sensorId: 'sensor-1'),
            ),
          ),
          tankRepositoryProvider.overrideWithValue(repository),
          tankSourceProvider.overrideWithValue(_FakeSource()),
        ],
        child: const GroundTankApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Pengaturan'));
    await tester.pump(const Duration(milliseconds: 500));

    CupertinoTextField heightField() => tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField).first,
    );

    expect(find.text('Terkunci'), findsOneWidget);
    expect(find.text('Simpan untuk semua HP'), findsNothing);
    expect(heightField().enabled, isFalse);

    Future<void> unlockWith(String pin) async {
      await tester.tap(find.text('Buka kunci untuk mengubah'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.byType(CupertinoTextField),
        ),
        pin,
      );
      await tester.tap(find.text('Buka kunci'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    await unlockWith('000000');
    expect(find.text('PIN salah.'), findsOneWidget);
    expect(find.text('Terkunci'), findsOneWidget);
    expect(heightField().enabled, isFalse);

    await unlockWith('123456');
    expect(repository.tried, ['000000', '123456']);
    expect(find.text('Terbuka'), findsOneWidget);
    expect(find.text('Simpan untuk semua HP'), findsOneWidget);
    expect(heightField().enabled, isTrue);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });
}
