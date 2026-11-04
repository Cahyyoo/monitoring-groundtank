import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groundtank/services/update_service.dart';
import 'package:groundtank/widgets/update_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ota_update/ota_update.dart';

Map<String, dynamic> _release({String tag = 'v1.2.0'}) => {
  'tag_name': tag,
  'body': ' Perbaikan grafik. ',
  'assets': [
    {
      'name': 'app-armeabi-v7a-release.apk',
      'browser_download_url': 'https://example.test/v7.apk',
      'size': 100,
    },
    {
      'name': 'app-arm64-v8a-release.apk',
      'browser_download_url': 'https://example.test/arm64.apk',
      'size': 18245632,
    },
  ],
};

const _sample = AppRelease(
  version: '1.2.0',
  notes: 'Perbaikan grafik.',
  apkUrl: 'https://example.test/arm64.apk',
  sizeBytes: 18245632,
);

void main() {
  group('isNewerVersion', () {
    test('compares number by number, not as text', () {
      expect(isNewerVersion('1.10.0', '1.9.0'), isTrue);
      expect(isNewerVersion('1.9.0', '1.10.0'), isFalse);
      expect(isNewerVersion('2.0.0', '1.99.99'), isTrue);
    });

    test('the same version is not newer', () {
      expect(isNewerVersion('1.1.0', '1.1.0'), isFalse);
      expect(isNewerVersion('1.1', '1.1.0'), isFalse);
    });

    test('ignores a leading v and a build or suffix', () {
      expect(isNewerVersion('v1.2.0', '1.1.0'), isTrue);
      expect(isNewerVersion('v1.1.0+5', '1.1.0'), isFalse);
      expect(isNewerVersion('1.2.0-beta', '1.1.0'), isTrue);
    });

    test('an unreadable tag is never newer', () {
      expect(isNewerVersion('terbaru', '1.1.0'), isFalse);
      expect(isNewerVersion('', '1.1.0'), isFalse);
    });
  });

  group('parseRelease', () {
    test('picks the APK of this architecture', () {
      final arm64 = parseRelease(_release(), Abi.androidArm64)!;
      expect(arm64.version, '1.2.0');
      expect(arm64.notes, 'Perbaikan grafik.');
      expect(arm64.apkUrl, 'https://example.test/arm64.apk');
      expect(arm64.sizeBytes, 18245632);
      expect(
        parseRelease(_release(), Abi.androidArm)!.apkUrl,
        'https://example.test/v7.apk',
      );
    });

    test('is null without an APK for this architecture', () {
      expect(parseRelease(_release(), Abi.androidX64), isNull);
      expect(parseRelease(_release(), Abi.windowsX64), isNull);
      expect(parseRelease({'tag_name': 'v1.2.0'}, Abi.androidArm64), isNull);
    });
  });

  group('fetchNewerRelease', () {
    Future<AppRelease?> fetchWith(
      Future<http.Response> Function(http.Request) handler, {
      String current = '1.1.0',
    }) => fetchNewerRelease(
      current,
      client: MockClient(handler),
      abi: Abi.androidArm64,
    );

    test('finds a newer release', () async {
      final release = await fetchWith((request) async {
        expect(request.url.path, endsWith('/releases/latest'));
        expect(request.url.path, contains('Cahyyoo/monitoring-groundtank'));
        return http.Response(jsonEncode(_release()), 200);
      });
      expect(release?.version, '1.2.0');
    });

    test('is null when already up to date', () async {
      final release = await fetchWith(
        (_) async => http.Response(jsonEncode(_release()), 200),
        current: '1.2.0',
      );
      expect(release, isNull);
    });

    test('stays quiet about every failure', () async {
      // No release yet, and GitHub's rate limit.
      for (final status in [404, 403, 500]) {
        expect(await fetchWith((_) async => http.Response('', status)), isNull);
      }
      expect(await fetchWith((_) async => http.Response('{bad', 200)), isNull);
      expect(
        await fetchWith((_) async => throw http.ClientException('offline')),
        isNull,
      );
    });
  });

  group('update dialog', () {
    late StreamController<OtaEvent> events;
    late int starts;

    Stream<OtaEvent> start(AppRelease _) {
      starts++;
      events = StreamController<OtaEvent>();
      return events.stream;
    }

    Future<void> send(WidgetTester tester, OtaEvent event) async {
      events.add(event);
      await tester.pump();
      await tester.pump();
    }

    Future<void> open(WidgetTester tester) async {
      starts = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => showUpdateDialog(context, _sample, start: start),
              child: const Text('buka'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
    }

    testWidgets('goes from offer to download to install', (tester) async {
      await open(tester);
      expect(find.text('Pembaruan tersedia'), findsOneWidget);
      expect(find.textContaining('17,4 MB'), findsOneWidget);
      expect(find.textContaining('Perbaikan grafik.'), findsOneWidget);
      expect(starts, 0);

      await tester.tap(find.text('Perbarui'));
      await tester.pump();
      expect(starts, 1);
      expect(find.text('Mengunduh versi 1.2.0'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      await send(tester, OtaEvent(OtaStatus.DOWNLOADING, '42'));
      expect(find.text('42%'), findsOneWidget);

      await send(
        tester,
        OtaEvent(OtaStatus.INSTALLING, 'Installation started'),
      );
      expect(find.text('Memasang pembaruan'), findsOneWidget);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Memasang pembaruan'), findsNothing);
    });

    testWidgets('"Nanti" closes it without downloading', (tester) async {
      await open(tester);
      await tester.tap(find.text('Nanti'));
      await tester.pumpAndSettle();
      expect(find.text('Pembaruan tersedia'), findsNothing);
      expect(starts, 0);
    });

    testWidgets('a tap outside does not close it', (tester) async {
      await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Pembaruan tersedia'), findsOneWidget);
    });

    testWidgets('a failure can be retried from the start', (tester) async {
      await open(tester);
      await tester.tap(find.text('Perbarui'));
      await tester.pump();
      await send(tester, OtaEvent(OtaStatus.DOWNLOADING, '42'));

      await send(tester, OtaEvent(OtaStatus.DOWNLOAD_ERROR, 'reset'));
      expect(find.text('Pembaruan gagal'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      await tester.pump();
      expect(starts, 2);
      expect(find.text('0%'), findsOneWidget);

      await send(
        tester,
        OtaEvent(OtaStatus.PERMISSION_NOT_GRANTED_ERROR, 'denied'),
      );
      expect(
        find.text('GroundTank belum diizinkan memasang aplikasi.'),
        findsOneWidget,
      );
    });
  });
}
