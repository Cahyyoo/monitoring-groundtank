import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:ota_update/ota_update.dart';

import '../services/format.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Starts downloading [AppRelease.apkUrl]; the events report progress and end
/// with Android's installer opening.
typedef UpdateStarter = Stream<OtaEvent> Function(AppRelease release);

// A new plugin object per attempt: one keeps its first stream for good, which
// would leave "Coba lagi" listening to a finished download.
Stream<OtaEvent> _startUpdate(AppRelease release) => OtaUpdate().execute(
  release.apkUrl,
  destinationFilename: 'groundtank-${release.version}.apk',
);

/// Offers [release], and walks through downloading and installing it. Only
/// its own buttons close it, so a stray tap cannot hide a running download.
Future<void> showUpdateDialog(
  BuildContext context,
  AppRelease release, {
  UpdateStarter start = _startUpdate,
}) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (_) => PopScope(
      canPop: false,
      child: UpdateDialog(release: release, start: start),
    ),
  );
}

enum _Stage { available, downloading, installing, failed }

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({required this.release, required this.start, super.key});

  final AppRelease release;
  final UpdateStarter start;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _Stage _stage = _Stage.available;
  int _percent = 0;
  String _failure = '';
  StreamSubscription<OtaEvent>? _download;

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }

  void _begin() {
    setState(() {
      _stage = _Stage.downloading;
      _percent = 0;
    });
    _download?.cancel();
    _download = widget
        .start(widget.release)
        .listen(_onEvent, onError: (Object e) => _fail('$e'));
  }

  void _onEvent(OtaEvent event) {
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        setState(() => _percent = int.tryParse(event.value ?? '') ?? _percent);
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() => _stage = _Stage.installing);
      case OtaStatus.CANCELED:
        break;
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _fail(
          event.value,
          message: 'GroundTank belum diizinkan memasang aplikasi.',
        );
      default:
        _fail(event.value);
    }
  }

  void _fail(
    String? detail, {
    String message =
        'Pembaruan gagal diunduh. Periksa koneksi internet lalu coba lagi.',
  }) {
    debugPrint('Update failed: $detail');
    setState(() {
      _stage = _Stage.failed;
      _failure = message;
    });
  }

  void _cancel() {
    unawaited(OtaUpdate().cancel());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    void close() => Navigator.of(context).pop();

    return switch (_stage) {
      _Stage.available => CupertinoAlertDialog(
        title: const Text('Pembaruan tersedia'),
        content: Text(
          [
            'Versi ${release.version} · ${Format.megabytes(release.sizeBytes)}',
            if (release.notes.isNotEmpty) release.notes,
          ].join('\n\n'),
        ),
        actions: [
          CupertinoDialogAction(onPressed: close, child: const Text('Nanti')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _begin,
            child: const Text('Perbarui'),
          ),
        ],
      ),
      _Stage.downloading => CupertinoAlertDialog(
        title: Text('Mengunduh versi ${release.version}'),
        content: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            children: [
              _ProgressBar(fraction: _percent / 100),
              const SizedBox(height: AppSpacing.sm),
              Text('$_percent%'),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: _cancel,
            child: const Text('Batal'),
          ),
        ],
      ),
      _Stage.installing => CupertinoAlertDialog(
        title: const Text('Memasang pembaruan'),
        content: const Text(
          'Ikuti jendela pemasangan Android. '
          'Aplikasi akan terbuka ulang setelah selesai.',
        ),
        actions: [
          CupertinoDialogAction(onPressed: close, child: const Text('Tutup')),
        ],
      ),
      _Stage.failed => CupertinoAlertDialog(
        title: const Text('Pembaruan gagal'),
        content: Text(_failure),
        actions: [
          CupertinoDialogAction(onPressed: close, child: const Text('Tutup')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _begin,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    };
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 6,
        color: palette.separator,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(color: palette.accent),
        ),
      ),
    );
  }
}
