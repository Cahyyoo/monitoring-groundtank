import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../background/background_monitor.dart';
import '../models/device.dart';
import '../models/sensor.dart';
import '../models/tank_config.dart';
import '../providers/config_provider.dart';
import '../providers/database_providers.dart';
import '../providers/shared_settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/format.dart';
import '../services/notification_service.dart';
import '../services/reading_conversion.dart';
import '../services/tank_rules.dart';
import '../services/tank_source.dart';
import '../theme/app_theme.dart';
import '../widgets/app_primitives.dart';
import '../widgets/ios/app_button.dart';
import '../widgets/ios/app_page.dart';
import '../widgets/ios/app_toast.dart';
import '../widgets/ios/inset_section.dart';
import '../widgets/ios/pin_dialog.dart';
import 'device_picker_screen.dart';
import 'sensor_picker_screen.dart';

/// Two kinds of settings, saved two ways.
///
/// The tank — device, sensors, dimensions, thresholds — is shared by every
/// phone through Supabase and locked: it can be looked at freely, and edited
/// only after the admin PIN is checked by the server. This phone's own
/// choices — polling, notifications, background — are saved on the phone.
///
/// Both are edited as drafts and applied with a button, because a
/// half-typed threshold must not start raising notifications. Appearance
/// applies at once.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _sharedKeys = {
    'deviceId',
    'sensorId',
    'floatSensorId',
    'tankHeightCm',
    'sensorToBottomCm',
    'capacityLiters',
    'fullThreshold',
    'emptyThreshold',
  };

  /// The configuration in effect, kept current while the screen is open.
  late TankConfig _saved;

  // Shared draft.
  String? _deviceId;
  String? _deviceName;
  String? _sensorId;
  String? _sensorName;
  String? _sensorUnit;
  String? _floatSensorId;
  String? _floatSensorName;
  late ValueKind _valueKind;
  final _height = TextEditingController();
  final _sensor = TextEditingController();
  final _capacity = TextEditingController();
  final _full = TextEditingController();
  final _empty = TextEditingController();

  // This phone's draft.
  late bool _notifications;
  late bool _background;
  final _poll = TextEditingController();

  /// The PIN the server accepted, held only in memory while unlocked.
  String? _pin;

  Map<String, String> _errors = const {};
  bool _sharedDirty = false;
  bool _localDirty = false;
  bool _savingShared = false;
  bool _savingLocal = false;
  bool _unlocking = false;
  bool _testing = false;

  bool get _unlocked => _pin != null;

  @override
  void initState() {
    super.initState();
    _saved = ref.read(configProvider);
    _fillShared(_saved);
    _fillLocal(_saved);
  }

  void _fillShared(TankConfig c) {
    _deviceId = c.deviceId;
    _deviceName = c.deviceName;
    _sensorId = c.sensorId;
    _sensorName = c.sensorName;
    _sensorUnit = c.sensorUnit;
    _floatSensorId = c.floatSensorId;
    _floatSensorName = c.floatSensorName;
    _valueKind = c.valueKind;
    _height.text = _plain(c.tankHeightCm);
    _sensor.text = _plain(c.sensorToBottomCm);
    _capacity.text = _plain(c.capacityLiters);
    _full.text = '${c.fullThreshold}';
    _empty.text = '${c.emptyThreshold}';
    _sharedDirty = false;
    _errors = {
      for (final e in _errors.entries)
        if (!_sharedKeys.contains(e.key)) e.key: e.value,
    };
  }

  void _fillLocal(TankConfig c) {
    _notifications = c.notificationsEnabled;
    _background = c.backgroundEnabled;
    _poll.text = '${c.pollSeconds}';
    _localDirty = false;
    _errors = {
      for (final e in _errors.entries)
        if (_sharedKeys.contains(e.key)) e.key: e.value,
    };
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  void dispose() {
    for (final c in [_height, _sensor, _capacity, _full, _empty, _poll]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touchShared() {
    setState(() {
      _sharedDirty = true;
      _errors = {
        for (final e in _errors.entries)
          if (!_sharedKeys.contains(e.key)) e.key: e.value,
      };
    });
  }

  void _touchLocal() {
    setState(() {
      _localDirty = true;
      _errors = Map.of(_errors)..remove('pollSeconds');
    });
  }

  /// The shared draft over the configuration in effect, or why it is wrong.
  (TankConfig?, Map<String, String>) _sharedDraft() {
    final bad = <String, String>{};
    double? dbl(TextEditingController c, String key) {
      final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
      if (v == null) bad[key] = 'Isi dengan angka.';
      return v;
    }

    int? whole(TextEditingController c, String key) {
      final v = int.tryParse(c.text.trim());
      if (v == null) bad[key] = 'Isi dengan bilangan bulat.';
      return v;
    }

    final height = dbl(_height, 'tankHeightCm');
    final sensor = dbl(_sensor, 'sensorToBottomCm');
    final capacity = dbl(_capacity, 'capacityLiters');
    final full = whole(_full, 'fullThreshold');
    final empty = whole(_empty, 'emptyThreshold');
    if (bad.isNotEmpty) return (null, bad);

    final config = _saved.copyWith(
      deviceId: () => _deviceId,
      deviceName: () => _deviceName,
      sensorId: () => _sensorId,
      sensorName: () => _sensorName,
      sensorUnit: () => _sensorUnit,
      floatSensorId: () => _floatSensorId,
      floatSensorName: () => _floatSensorName,
      valueKind: _valueKind,
      tankHeightCm: height,
      sensorToBottomCm: sensor,
      capacityLiters: capacity,
      fullThreshold: full,
      emptyThreshold: empty,
    );
    final errors = {
      for (final e in validateConfig(config).entries)
        if (_sharedKeys.contains(e.key)) e.key: e.value,
    };
    return (errors.isEmpty ? config : null, errors);
  }

  /// This phone's draft over the configuration in effect, or why it is wrong.
  (TankConfig?, Map<String, String>) _localDraft() {
    final poll = int.tryParse(_poll.text.trim());
    if (poll == null) {
      return (null, {'pollSeconds': 'Isi dengan bilangan bulat.'});
    }
    final config = _saved.copyWith(
      pollSeconds: poll,
      notificationsEnabled: _notifications,
      backgroundEnabled: _background,
    );
    final error = validateConfig(config)['pollSeconds'];
    return error == null ? (config, const {}) : (null, {'pollSeconds': error});
  }

  void _showInvalid(Map<String, String> errors) {
    setState(() => _errors = {..._errors, ...errors});
    AppToast.show(
      context,
      'Periksa kembali isian yang ditandai merah.',
      icon: CupertinoIcons.exclamationmark_circle,
    );
  }

  Future<void> _unlock() async {
    final pin = await showPinDialog(
      context,
      title: 'Buka kunci pengaturan',
      message: 'Perubahan berlaku untuk semua HP yang memakai aplikasi ini.',
    );
    if (pin == null || !mounted) return;
    setState(() => _unlocking = true);
    try {
      await ref.read(sharedSettingsProvider.notifier).verifyPin(pin);
      if (!mounted) return;
      setState(() => _pin = pin);
      AppToast.show(context, 'Kunci dibuka', icon: CupertinoIcons.lock_open);
    } on TankSourceException catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.message, icon: CupertinoIcons.lock);
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  /// Locks again and drops any unsaved shared edits.
  void _lock() {
    setState(() {
      _pin = null;
      _fillShared(_saved);
    });
  }

  Future<void> _saveShared() async {
    final pin = _pin;
    if (pin == null) return;
    final (config, errors) = _sharedDraft();
    if (config == null) return _showInvalid(errors);
    setState(() => _savingShared = true);
    try {
      await ref.read(sharedSettingsProvider.notifier).save(pin, config);
      if (!mounted) return;
      setState(() {
        _pin = null;
        _saved = ref.read(configProvider);
        _fillShared(_saved);
      });
      AppToast.show(
        context,
        'Disimpan untuk semua HP',
        icon: CupertinoIcons.checkmark_circle,
      );
    } on TankSourceException catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.message, icon: CupertinoIcons.xmark_circle);
    } finally {
      if (mounted) setState(() => _savingShared = false);
    }
  }

  Future<void> _saveLocal() async {
    final (config, errors) = _localDraft();
    if (config == null) return _showInvalid(errors);
    setState(() => _savingLocal = true);
    try {
      if (config.notificationsEnabled && !_saved.notificationsEnabled) {
        await NotificationService.requestPermission();
      }
      await ref.read(configProvider.notifier).saveLocal(config);
      if (!mounted) return;
      setState(() {
        _saved = ref.read(configProvider);
        _fillLocal(_saved);
      });
      AppToast.show(
        context,
        'Pengaturan HP ini disimpan',
        icon: CupertinoIcons.checkmark_circle,
      );
    } catch (e) {
      debugPrint('Could not save settings: $e');
      if (!mounted) return;
      AppToast.show(
        context,
        'Gagal menyimpan pengaturan. Coba lagi.',
        icon: CupertinoIcons.xmark_circle,
      );
    } finally {
      // Whatever happened, the button must not keep spinning.
      if (mounted) setState(() => _savingLocal = false);
    }
  }

  Future<void> _testConnection() async {
    final (config, errors) = _sharedDraft();
    if (config == null) {
      setState(() => _errors = {..._errors, ...errors});
      return;
    }
    setState(() => _testing = true);
    String message;
    IconData icon;
    try {
      final source = TankSource.forConfig(
        config,
        repository: ref.read(tankRepositoryProvider),
      );
      final reading = await source.fetch();
      message = [
        'Terhubung · air ${Format.percent(reading.percent)}',
        if (config.floatSensorId != null)
          'pelampung ${Format.floatState(reading.floatFull).toLowerCase()}',
        Format.relative(reading.measuredAt),
      ].join(' · ');
      icon = CupertinoIcons.checkmark_circle;
    } catch (e) {
      message = e.toString();
      icon = CupertinoIcons.xmark_circle;
    }
    if (!mounted) return;
    setState(() => _testing = false);
    AppToast.show(context, message, icon: icon);
  }

  Future<void> _sendTest() async {
    final granted = await NotificationService.requestPermission();
    await NotificationService.showTest();
    if (!mounted) return;
    if (!granted) {
      AppToast.show(
        context,
        'Izin notifikasi belum diberikan.',
        icon: CupertinoIcons.bell_slash,
      );
    }
  }

  Future<void> _pickDevice() async {
    final device = await Navigator.of(context).push<Device>(
      CupertinoPageRoute(
        builder: (_) => DevicePickerScreen(selectedId: _deviceId),
      ),
    );
    if (device == null || !mounted) return;
    setState(() {
      if (device.id != _deviceId) {
        // Another device's sensors are other sensors.
        _sensorId = null;
        _sensorName = null;
        _sensorUnit = null;
        _floatSensorId = null;
        _floatSensorName = null;
      }
      _deviceId = device.id;
      _deviceName = device.name;
    });
    _touchShared();
  }

  Future<Sensor?> _chooseSensor(SensorPurpose purpose) {
    final deviceId = _deviceId;
    if (deviceId == null) return Future.value();
    final isFloat = purpose == SensorPurpose.float;
    return Navigator.of(context).push<Sensor>(
      CupertinoPageRoute(
        builder: (_) => SensorPickerScreen(
          deviceId: deviceId,
          deviceName: _deviceName ?? '',
          purpose: purpose,
          selectedId: isFloat ? _floatSensorId : _sensorId,
          excludedId: isFloat ? _sensorId : _floatSensorId,
        ),
      ),
    );
  }

  Future<void> _pickSensor() async {
    final sensor = await _chooseSensor(SensorPurpose.level);
    if (sensor == null || !mounted) return;
    setState(() {
      _sensorId = sensor.id;
      _sensorName = sensor.name;
      _sensorUnit = sensor.unit;
      _valueKind = inferValueKind(sensor);
    });
    _touchShared();
  }

  Future<void> _pickFloat() async {
    final sensor = await _chooseSensor(SensorPurpose.float);
    if (sensor == null || !mounted) return;
    setState(() {
      _floatSensorId = sensor.id;
      _floatSensorName = sensor.name;
    });
    _touchShared();
  }

  void _clearFloat() {
    setState(() {
      _floatSensorId = null;
      _floatSensorName = null;
    });
    _touchShared();
  }

  /// The first error among [keys], for a section footer.
  String? _errorIn(List<String> keys) =>
      keys.map((k) => _errors[k]).whereType<String>().firstOrNull;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final themeMode = ref.watch(themeModeProvider);
    final shared = ref.watch(sharedSettingsProvider);
    final databaseAvailable = ref.watch(tankRepositoryProvider) != null;
    final editable = databaseAvailable && _unlocked;

    // Another phone, or the admin in Supabase, changed something: show it,
    // unless it would overwrite edits in progress here.
    ref.listen<TankConfig>(configProvider, (_, next) {
      setState(() {
        _saved = next;
        if (!_sharedDirty) _fillShared(next);
        if (!_localDirty) _fillLocal(next);
      });
    });

    final sourceError = _errorIn(['deviceId', 'sensorId', 'floatSensorId']);
    final tankError = _errorIn([
      'tankHeightCm',
      'sensorToBottomCm',
      'capacityLiters',
    ]);
    final thresholdError = _errorIn(['fullThreshold', 'emptyThreshold']);
    final pollError = _errors['pollSeconds'];

    Widget check(bool on) => on
        ? Icon(CupertinoIcons.check_mark, size: 20, color: palette.accent)
        : const SizedBox(width: 20);

    final String lockSubtitle = switch (shared) {
      _ when !databaseAvailable => 'Supabase belum dikonfigurasi',
      SharedSettingsState(:final error?) => error,
      SharedSettingsState(exists: false) =>
        'Belum ada pengaturan bersama; HP ini memakai pengaturannya sendiri.',
      SharedSettingsState(:final updatedAt?) =>
        'Berlaku untuk semua HP · diubah ${Format.dateTime(updatedAt)}',
      _ => 'Berlaku untuk semua HP',
    };

    final sourceFooter = switch (_valueKind) {
      _ when !databaseAvailable =>
        'Supabase belum dikonfigurasi: build ini tidak membawa SUPABASE_URL dan '
            'SUPABASE_PUBLISHABLE_KEY (jalankan dengan --dart-define-from-file=env.json).',
      _ when sourceError != null => sourceError,
      ValueKind.percent =>
        'Nilai sensor dibaca langsung sebagai persen terisi.',
      ValueKind.levelCm =>
        'Nilai sensor dibaca sebagai tinggi air dari dasar tangki.',
      ValueKind.distanceCm =>
        'Nilai sensor dibaca sebagai jarak sensor ke permukaan air; tinggi air = '
            'jarak sensor ke dasar – nilai ini.',
    };

    return AppPage.list(
      title: 'Pengaturan',
      children: [
        InsetSection(
          header: 'Pengaturan tangki',
          footer:
              'Perangkat, sensor, dimensi, dan ambang sama untuk semua HP. '
              'Mengubahnya butuh PIN admin, yang dibuat di Supabase dan tidak '
              'disimpan di HP.',
          children: [
            InsetRow(
              leading: IconTile(
                icon: _unlocked
                    ? CupertinoIcons.lock_open_fill
                    : CupertinoIcons.lock_fill,
                tone: _unlocked ? palette.warning : palette.info,
              ),
              title: _unlocked ? 'Terbuka' : 'Terkunci',
              subtitle: lockSubtitle,
              trailing: _unlocking ? const CupertinoActivityIndicator() : null,
            ),
            if (databaseAvailable)
              InsetRow(
                title: _unlocked
                    ? 'Kunci kembali'
                    : 'Buka kunci untuk mengubah',
                titleStyle: AppText.body.copyWith(color: palette.accent),
                onTap: _unlocking ? null : (_unlocked ? _lock : _unlock),
              ),
          ],
        ),
        InsetSection(
          header: 'Sensor',
          footer: sourceFooter,
          footerIsError: !databaseAvailable || sourceError != null,
          children: [
            InsetRow(
              title: 'Perangkat',
              subtitle: _deviceName ?? 'Belum dipilih',
              showChevron: editable,
              onTap: editable ? _pickDevice : null,
            ),
            InsetRow(
              title: 'Sensor ketinggian',
              subtitle: _sensorId == null
                  ? (_deviceId == null
                        ? 'Pilih perangkat dulu'
                        : 'Belum dipilih')
                  : [
                      ?_sensorName,
                      if (_sensorUnit != null) 'unit $_sensorUnit',
                    ].join(' · '),
              showChevron: editable && _deviceId != null,
              onTap: editable && _deviceId != null ? _pickSensor : null,
            ),
            if (_sensorId != null)
              InsetCustomRow(
                child: SizedBox(
                  width: double.infinity,
                  child: IgnorePointer(
                    ignoring: !editable,
                    child: Opacity(
                      opacity: editable ? 1 : 0.6,
                      child: CupertinoSlidingSegmentedControl<ValueKind>(
                        groupValue: _valueKind,
                        children: {
                          for (final kind in ValueKind.values)
                            kind: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                switch (kind) {
                                  ValueKind.percent => 'Persen',
                                  ValueKind.levelCm => 'Tinggi air',
                                  ValueKind.distanceCm => 'Jarak',
                                },
                                style: AppText.footnote.copyWith(
                                  color: palette.label,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        },
                        onValueChanged: (kind) {
                          if (kind == null) return;
                          setState(() => _valueKind = kind);
                          _touchShared();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            InsetRow(
              title: 'Sensor pelampung',
              subtitle:
                  _floatSensorName ??
                  (_floatSensorId == null
                      ? 'Opsional · penanda tangki penuh (1 = penuh)'
                      : 'Sensor terpilih'),
              showChevron: editable && _deviceId != null,
              onTap: editable && _deviceId != null ? _pickFloat : null,
            ),
            if (editable && _floatSensorId != null)
              InsetRow(
                title: 'Tidak pakai pelampung',
                isDestructive: true,
                onTap: _clearFloat,
              ),
            if (_sensorId != null)
              InsetRow(
                title: _testing ? 'Menguji koneksi…' : 'Uji koneksi',
                titleStyle: AppText.body.copyWith(color: palette.accent),
                trailing: _testing ? const CupertinoActivityIndicator() : null,
                onTap: _testing ? null : _testConnection,
              ),
          ],
        ),
        InsetSection(
          header: 'Dimensi tangki',
          footer:
              tankError ??
              'Jarak sensor ke dasar hanya dipakai bila nilai sensor berupa jarak ke permukaan air.',
          footerIsError: tankError != null,
          children: [
            _NumberRow(
              label: 'Tinggi air maksimum',
              controller: _height,
              suffix: 'cm',
              readOnly: !editable,
              error: _errors.containsKey('tankHeightCm'),
              onChanged: _touchShared,
            ),
            _NumberRow(
              label: 'Jarak sensor ke dasar',
              controller: _sensor,
              suffix: 'cm',
              readOnly: !editable,
              error: _errors.containsKey('sensorToBottomCm'),
              onChanged: _touchShared,
            ),
            _NumberRow(
              label: 'Kapasitas',
              controller: _capacity,
              suffix: 'L',
              readOnly: !editable,
              error: _errors.containsKey('capacityLiters'),
              onChanged: _touchShared,
            ),
          ],
        ),
        InsetSection(
          header: 'Ambang notifikasi',
          footer:
              thresholdError ??
              'Status baru lepas dari penuh/kosong setelah air bergeser '
                  '${hysteresisPercent.round()}% dari batasnya, agar riak air tidak memicu notifikasi berulang.',
          footerIsError: thresholdError != null,
          children: [
            _NumberRow(
              label: 'Batas penuh',
              controller: _full,
              suffix: '%',
              decimal: false,
              readOnly: !editable,
              error: _errors.containsKey('fullThreshold'),
              onChanged: _touchShared,
            ),
            _NumberRow(
              label: 'Batas kosong',
              controller: _empty,
              suffix: '%',
              decimal: false,
              readOnly: !editable,
              error: _errors.containsKey('emptyThreshold'),
              onChanged: _touchShared,
            ),
          ],
        ),
        if (editable)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: AppButton(
              label: 'Simpan untuk semua HP',
              icon: CupertinoIcons.checkmark_alt,
              isBusy: _savingShared,
              onPressed: _sharedDirty ? _saveShared : null,
            ),
          ),
        InsetSection(
          header: 'HP ini',
          footer:
              pollError ??
              (BackgroundMonitor.isSupported
                  ? 'Hanya untuk HP ini. Saat aplikasi ditutup, Android memeriksa '
                        'tangki paling cepat tiap 15 menit.'
                  : 'Hanya untuk HP ini. Notifikasi dikirim selama aplikasi terbuka.'),
          footerIsError: pollError != null,
          children: [
            _NumberRow(
              label: 'Interval pembaruan',
              controller: _poll,
              suffix: 'detik',
              decimal: false,
              error: pollError != null,
              onChanged: _touchLocal,
            ),
            _SwitchRow(
              title: 'Peringatan penuh & kosong',
              value: _notifications,
              onChanged: (v) {
                setState(() => _notifications = v);
                _touchLocal();
              },
            ),
            if (BackgroundMonitor.isSupported)
              _SwitchRow(
                title: 'Pantau di latar belakang',
                value: _background,
                onChanged: (v) {
                  setState(() => _background = v);
                  _touchLocal();
                },
              ),
            InsetRow(
              title: 'Kirim notifikasi uji',
              titleStyle: AppText.body.copyWith(color: palette.accent),
              onTap: _sendTest,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: AppButton(
            label: 'Simpan pengaturan HP ini',
            icon: CupertinoIcons.checkmark_alt,
            isBusy: _savingLocal,
            onPressed: _localDirty ? _saveLocal : null,
          ),
        ),
        InsetSection(
          header: 'Tampilan',
          children: [
            for (final (label, mode) in const [
              ('Ikuti sistem', ThemeMode.system),
              ('Terang', ThemeMode.light),
              ('Gelap', ThemeMode.dark),
            ])
              InsetRow(
                title: label,
                trailing: check(themeMode == mode),
                onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
              ),
          ],
        ),
        Center(
          child: Text(
            'GroundTank 1.0.0',
            style: AppText.caption.copyWith(color: palette.tertiaryLabel),
          ),
        ),
      ],
    );
  }
}

/// A label on the left, a right-aligned number field and its unit on the
/// right. Read-only while the shared settings are locked.
class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.onChanged,
    this.decimal = true,
    this.readOnly = false,
    this.error = false,
  });

  final String label;
  final TextEditingController controller;
  final String suffix;
  final VoidCallback onChanged;
  final bool decimal;
  final bool readOnly;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colour = error
        ? palette.danger.foreground
        : (readOnly ? palette.secondaryLabel : palette.label);
    return InsetCustomRow(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.body.copyWith(color: palette.label),
            ),
          ),
          SizedBox(
            width: 96,
            child: CupertinoTextField.borderless(
              controller: controller,
              enabled: !readOnly,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
                ),
              ],
              style: AppText.body.copyWith(
                color: colour,
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            child: Text(
              suffix,
              style: AppText.subhead.copyWith(color: palette.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InsetCustomRow(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppText.body.copyWith(color: palette.label),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: palette.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
