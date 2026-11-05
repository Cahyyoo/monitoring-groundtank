import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/main.dart';
import 'package:groundtank/widgets/dashboard/tank_gauge.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The splash's tank: the dashboard's always has threshold lines.
final _splashTank = find.byWidgetPredicate(
  (w) =>
      w is CustomPaint &&
      w.painter is TankPainter &&
      (w.painter! as TankPainter).full == null,
);

TankPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_splashTank).painter! as TankPainter;

Finder get _title => find.descendant(
  of: find.ancestor(of: _splashTank, matching: find.byType(Column)),
  matching: find.text('GroundTank'),
);

double _titleOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: _title, matching: find.byType(Opacity)).first,
    )
    .opacity;

Future<void> _pumpApp(WidgetTester tester, {required bool splash}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(child: GroundTankApp(showSplash: splash)),
  );
  // The first frame only starts the animation's clock.
  await tester.pump();
}

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  testWidgets('the tank fills, the name appears, then the app shows', (
    tester,
  ) async {
    await _pumpApp(tester, splash: true);
    expect(_painter(tester).level, 0);
    expect(_titleOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 600));
    final rising = _painter(tester).level;
    expect(rising, inExclusiveRange(0, 0.92));

    await tester.pump(const Duration(milliseconds: 800));
    expect(_painter(tester).level, closeTo(0.92, 0.001));
    expect(_titleOpacity(tester), 1);

    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(_splashTank, findsNothing);

    // The app underneath took taps again, and it was never rebuilt away.
    await tester.tap(find.text('Pengaturan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Versi aplikasi'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('taps do not reach the app during the splash', (tester) async {
    await _pumpApp(tester, splash: true);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Pengaturan'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Versi aplikasi'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with less motion the tank is already full and still', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpApp(tester, splash: true);
    expect(_painter(tester).level, 0.92);

    await tester.pump(const Duration(milliseconds: 600));
    expect(_painter(tester).level, 0.92);
    expect(_painter(tester).phase, 0);

    await tester.pump(const Duration(milliseconds: 1450));
    await tester.pump();
    expect(_splashTank, findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no splash unless asked for', (tester) async {
    await _pumpApp(tester, splash: false);
    expect(_splashTank, findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
