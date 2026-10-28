import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../background/background_monitor.dart';
import '../models/tank_config.dart';
import '../models/device.dart';
import '../models/sensor.dart';
import '../providers/config_provider.dart';
import '../providers/database_providers.dart';
import '../providers/theme_provider.dart';
import '../services/format.dart';
import '../services/notification_service.dart';
import '../services/reading_conversion.dart';
import '../services/tank_rules.dart';
import '../services/tank_source.dart';
import '../theme/app_theme.dart';
import '../widgets/ios/app_button.dart';
import '../widgets/ios/app_page.dart';
import '../widgets/ios/app_toast.dart';
import '../widgets/ios/inset_section.dart';
import 'device_picker_screen.dart';
import 'sensor_picker_screen.dart';

/// The data source, the tank's dimensions, the thresholds, and appearance.
///
/// Tank settings are edited as a draft and applied together with one button,
/// because a half-typed threshold must not start raising notifications.
/// Appearance applies at once, as in Atara.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TankConfig _saved;
  late SourceMode _source;
  late bool _notifications;
  late bool _background;
  String? _deviceId;
  String? _deviceName;
  String? _sensorId;
  String? _sensorName;
  String? _sensorUnit;
  late ValueKind _valueKind;

  final _height = TextEditingController();
  final _sensor = TextEditingController();
  final _capacity = TextEditingController();
  final _full = TextEditingController();
  final _empty = TextEditingController();
  final _poll = TextEditingController();

  Map<String, String> _errors = const {};
  bool _dirty = false;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _fill(ref.read(configProvider));
  }

  void _fill(TankConfig c) {
    _saved = c;
    _source = c.sourceMode;
    _notifications = c.notificationsEnabled;
    _background = c.backgroundEnabled;
    _deviceId = c.deviceId;
    _deviceName = c.deviceName;
    _sensorId = c.sensorId;
    _sensorName = c.sensorName;
    _sensorUnit = c.sensorUnit;
    _valueKind = c.valueKind;
    _height.text = _plain(c.tankHeightCm);
    _sensor.text = _plain(c.sensorToBottomCm);
    _capacity.text = _plain(c.capacityLiters);
    _full.text = '${c.fullThreshold}';
    _empty.text = '${c.emptyThreshold}';
    _poll.text = '${c.pollSeconds}';
    _errors = const {};
    _dirty = false;
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

  void _touch() {
    if (!_dirty || _errors.isNotEmpty) {
      setState(() {
        _dirty = true;
        _errors = const {};
      });
    }
  }

  /// The draft as a configuration, or the fields that are not numbers.
  (TankConfig?, Map<String, String>) _draft() {
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
    final poll = whole(_poll, 'pollSeconds');
    if (bad.isNotEmpty) return (null, bad);

    final config = _saved.copyWith(
      sourceMode: _source,
      deviceId: () => _deviceId,
      deviceName: () => _deviceName,
      sensorId: () => _sensorId,
      sensorName: () => _sensorName,
      sensorUnit: () => _sensorUnit,
      valueKind: _valueKind,
      tankHeightCm: height,
      sensorToBottomCm: sensor,
      capacityLiters: capacity,
      fullThreshold: full,
      emptyThreshold: empty,
      pollSeconds: poll,
      notificationsEnabled: _notifications,
      backgroundEnabled: _background,
    );
    final errors = validateConfig(config);
    return (errors.isEmpty ? config : null, errors);
  }

  Future<void> _save() async {
    final (config, errors) = _draft();
    if (config == null) {
      setState(() => _errors = errors);
      AppToast.show(
        context,
        'Periksa kembali isian yang ditandai merah.',
        icon: CupertinoIcons.exclamationmark_circle,
      );
      return;
    }
    setState(() => _saving = true);
    if (config.notificationsEnabled && !_saved.notificationsEnabled) {
      await NotificationService.requestPermission();
    }
    await ref.read(configProvider.notifier).save(config);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _fill(config);
    });
    AppToast.show(
      context,
      'Pengaturan disimpan',
      icon: CupertinoIcons.checkmark_circle,
    );
  }

  Future<void> _testConnection() async {
    final (config, errors) = _draft();
    if (config == null) {
      setState(() => _errors = errors);
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
      message =
          'Terhubung · air ${Format.percent(reading.percent)} · '
          '${Format.relative(reading.measuredAt)}';
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
      }
      _deviceId = device.id;
      _deviceName = device.name;
    });
    _touch();
  }

  Future<void> _pickSensor() async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    final sensor = await Navigator.of(context).push<Sensor>(
      CupertinoPageRoute(
        builder: (_) => SensorPickerScreen(
          deviceId: deviceId,
          deviceName: _deviceName ?? '',
          selectedId: _sensorId,
        ),
      ),
    );
    if (sensor == null || !mounted) return;
    setState(() {
      _sensorId = sensor.id;
      _sensorName = sensor.name;
      _sensorUnit = sensor.unit;
      _valueKind = inferValueKind(sensor);
    });
    _touch();
  }

  /// The first error among [keys], for a section footer.
  String? _errorIn(List<String> keys) =>
      keys.map((k) => _errors[k]).whereType<String>().firstOrNull;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final themeMode = ref.watch(themeModeProvider);

    final sourceError = _errorIn(['deviceId', 'sensorId']);
    final tankError = _errorIn([
      'tankHeightCm',
      'sensorToBottomCm',
      'capacityLiters',
    ]);
    final thresholdError = _errorIn([
      'fullThreshold',
      'emptyThreshold',
      'pollSeconds',
    ]);
    final databaseAvailable = ref.watch(tankRepositoryProvider) != null;

    Widget check(bool on) => on
        ? Icon(CupertinoIcons.check_mark, size: 20, color: palette.accent)
        : const SizedBox(width: 20);

    void selectSource(SourceMode mode) {
      setState(() => _source = mode);
      _touch();
    }

    final sourceFooter = switch (_source) {
      _ when sourceError != null => sourceError,
      SourceMode.demo when !databaseAvailable =>
        'Database belum tersedia: build ini tidak membawa SUPABASE_URL dan '
            'SUPABASE_PUBLISHABLE_KEY (jalankan dengan --dart-define-from-file=env.json).',
      SourceMode.demo =>
        'Tangki simulasi yang terisi dan terkuras sendiri dalam siklus 6 menit.',
      SourceMode.database => switch (_valueKind) {
        ValueKind.percent =>
          'Nilai sensor dibaca langsung sebagai persen terisi.',
        ValueKind.levelCm =>
          'Nilai sensor dibaca sebagai tinggi air dari dasar tangki.',
        ValueKind.distanceCm =>
          'Nilai sensor dibaca sebagai jarak sensor ke permukaan air; tinggi air = '
              'jarak sensor ke dasar – nilai ini.',
      },
    };

    return AppPage.list(
      title: 'Pengaturan',
      children: [
        InsetSection(
          header: 'Sumber data',
          footer: sourceFooter,
          footerIsError: sourceError != null,
          children: [
            InsetRow(
              title: 'Demo (simulasi)',
              trailing: check(_source == SourceMode.demo),
              onTap: () => selectSource(SourceMode.demo),
            ),
            InsetRow(
              title: 'Database (Supabase)',
              subtitle: databaseAvailable ? null : 'Belum dikonfigurasi',
              trailing: check(_source == SourceMode.database),
              onTap: databaseAvailable
                  ? () => selectSource(SourceMode.database)
                  : null,
            ),
            if (_source == SourceMode.database) ...[
              InsetRow(
                title: 'Perangkat',
                subtitle: _deviceName ?? 'Belum dipilih',
                showChevron: true,
                onTap: _pickDevice,
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
                showChevron: _deviceId != null,
                onTap: _deviceId == null ? null : _pickSensor,
              ),
              InsetCustomRow(
                child: SizedBox(
                  width: double.infinity,
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
                      _touch();
                    },
                  ),
                ),
              ),
              InsetRow(
                title: _testing ? 'Menguji koneksi…' : 'Uji koneksi',
                titleStyle: AppText.body.copyWith(color: palette.accent),
                trailing: _testing ? const CupertinoActivityIndicator() : null,
                onTap: _testing ? null : _testConnection,
              ),
            ],
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
              error: _errors.containsKey('tankHeightCm'),
              onChanged: _touch,
            ),
            _NumberRow(
              label: 'Jarak sensor ke dasar',
              controller: _sensor,
              suffix: 'cm',
              error: _errors.containsKey('sensorToBottomCm'),
              onChanged: _touch,
            ),
            _NumberRow(
              label: 'Kapasitas',
              controller: _capacity,
              suffix: 'L',
              error: _errors.containsKey('capacityLiters'),
              onChanged: _touch,
            ),
          ],
        ),
        InsetSection(
          header: 'Ambang & pembaruan',
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
              error: _errors.containsKey('fullThreshold'),
              onChanged: _touch,
            ),
            _NumberRow(
              label: 'Batas kosong',
              controller: _empty,
              suffix: '%',
              decimal: false,
              error: _errors.containsKey('emptyThreshold'),
              onChanged: _touch,
            ),
            _NumberRow(
              label: 'Interval pembaruan',
              controller: _poll,
              suffix: 'detik',
              decimal: false,
              error: _errors.containsKey('pollSeconds'),
              onChanged: _touch,
            ),
          ],
        ),
        InsetSection(
          header: 'Notifikasi',
          footer: BackgroundMonitor.isSupported
              ? 'Saat aplikasi ditutup, Android memeriksa tangki paling cepat tiap 15 menit.'
              : 'Notifikasi dikirim selama aplikasi terbuka.',
          children: [
            _SwitchRow(
              title: 'Peringatan penuh & kosong',
              value: _notifications,
              onChanged: (v) {
                setState(() => _notifications = v);
                _touch();
              },
            ),
            if (BackgroundMonitor.isSupported)
              _SwitchRow(
                title: 'Pantau di latar belakang',
                value: _background,
                onChanged: (v) {
                  setState(() => _background = v);
                  _touch();
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
            label: 'Simpan pengaturan',
            icon: CupertinoIcons.checkmark_alt,
            isBusy: _saving,
            onPressed: _dirty ? _save : null,
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
/// right.
class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.onChanged,
    this.decimal = true,
    this.error = false,
  });

  final String label;
  final TextEditingController controller;
  final String suffix;
  final VoidCallback onChanged;
  final bool decimal;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colour = error ? palette.danger.foreground : palette.label;
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
