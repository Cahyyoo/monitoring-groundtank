import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/models/chart_range.dart';
import 'package:groundtank/widgets/dashboard/date_range_sheet.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  final today = DateTime(2026, 11, 18);

  /// Opens the sheet and hands back what it resolves to once it closes.
  Future<List<DateSpan?>> open(WidgetTester tester, {DateSpan? initial}) async {
    final results = <DateSpan?>[];
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => results.add(
              await showDateRangeSheet(context, initial: initial, today: today),
            ),
            child: const Text('buka'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> tapDay(WidgetTester tester, int day) async {
    await tester.tap(find.text('$day'));
    await tester.pump();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
  }

  bool applyEnabled(WidgetTester tester) => tester
      .widget<CupertinoButton>(
        find.ancestor(
          of: find.text('Terapkan'),
          matching: find.byType(CupertinoButton),
        ),
      )
      .enabled;

  testWidgets('two taps make a range', (tester) async {
    final results = await open(tester);
    expect(find.text('Ketuk tanggal awal'), findsOneWidget);

    await tapDay(tester, 3);
    expect(find.text('3 Nov 2026'), findsOneWidget);
    expect(find.text('Ketuk tanggal akhir'), findsOneWidget);

    await tapDay(tester, 9);
    expect(find.text('9 Nov 2026'), findsOneWidget);

    await apply(tester);
    expect(results.single?.firstDay, DateTime(2026, 11, 3));
    expect(results.single?.lastDay, DateTime(2026, 11, 9));
  });

  testWidgets('a later day tapped first is swapped into place', (tester) async {
    final results = await open(tester);
    await tapDay(tester, 9);
    await tapDay(tester, 3);
    await apply(tester);
    expect(results.single?.firstDay, DateTime(2026, 11, 3));
    expect(results.single?.lastDay, DateTime(2026, 11, 9));
  });

  testWidgets('the same day twice, or once, is a single day', (tester) async {
    final twice = await open(tester);
    await tapDay(tester, 5);
    await tapDay(tester, 5);
    await apply(tester);
    expect(twice.single?.firstDay, DateTime(2026, 11, 5));
    expect(twice.single?.lastDay, DateTime(2026, 11, 5));

    final once = await open(tester);
    await tapDay(tester, 5);
    await apply(tester);
    expect(once.single?.firstDay, DateTime(2026, 11, 5));
    expect(once.single?.lastDay, DateTime(2026, 11, 5));
  });

  testWidgets('a third tap starts a new range', (tester) async {
    final results = await open(tester);
    await tapDay(tester, 3);
    await tapDay(tester, 9);
    await tapDay(tester, 12);
    expect(find.text('Ketuk tanggal akhir'), findsOneWidget);
    await tapDay(tester, 14);
    await apply(tester);
    expect(results.single?.firstDay, DateTime(2026, 11, 12));
    expect(results.single?.lastDay, DateTime(2026, 11, 14));
  });

  testWidgets('days after today cannot be chosen', (tester) async {
    await open(tester);
    await tapDay(tester, 19);
    expect(find.text('19 Nov 2026'), findsNothing);
    expect(applyEnabled(tester), isFalse);

    await tapDay(tester, 18);
    expect(find.text('18 Nov 2026'), findsOneWidget);
  });

  testWidgets('moves back through months but not past this one', (
    tester,
  ) async {
    final results = await open(tester);
    expect(find.text('November 2026'), findsOneWidget);

    CupertinoButton forward() => tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.byIcon(CupertinoIcons.chevron_right),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(forward().enabled, isFalse);

    await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
    await tester.pump();
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(forward().enabled, isTrue);

    // A whole month in the past, spanning into this one.
    await tapDay(tester, 30);
    await tester.tap(find.byIcon(CupertinoIcons.chevron_right));
    await tester.pump();
    await tapDay(tester, 2);
    await apply(tester);
    expect(results.single?.firstDay, DateTime(2026, 10, 30));
    expect(results.single?.lastDay, DateTime(2026, 11, 2));
  });

  testWidgets('every month lays out at the same height', (tester) async {
    await open(tester);
    final height = tester.getSize(find.byType(SingleChildScrollView)).height;
    for (var i = 0; i < 14; i++) {
      await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
      await tester.pump();
      expect(tester.getSize(find.byType(SingleChildScrollView)).height, height);
    }
  });

  testWidgets('"Terapkan" waits for a day', (tester) async {
    await open(tester);
    expect(applyEnabled(tester), isFalse);
    await tapDay(tester, 3);
    expect(applyEnabled(tester), isTrue);
  });

  testWidgets('"Batal" resolves to nothing', (tester) async {
    final results = await open(tester);
    await tapDay(tester, 3);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('a range already chosen opens on its month', (tester) async {
    await open(
      tester,
      initial: DateSpan(DateTime(2026, 9, 2), DateTime(2026, 9, 12)),
    );
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('2 Sep 2026'), findsOneWidget);
    expect(find.text('12 Sep 2026'), findsOneWidget);
  });

  testWidgets('stays narrow on a tablet', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 1920)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showDateRangeSheet(context, today: today),
            child: const Text('buka'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SingleChildScrollView)).width, 480);
  });
}
