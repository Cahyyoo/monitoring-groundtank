import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sensor.dart';
import '../providers/database_providers.dart';
import '../services/format.dart';
import '../services/reading_conversion.dart';
import '../theme/app_theme.dart';
import '../widgets/app_primitives.dart';
import '../widgets/ios/async_list_page.dart';
import '../widgets/ios/inset_section.dart';

/// What the sensor being picked is for.
enum SensorPurpose { level, float }

/// The sensors wired to one device (`device_sensors`), to choose the one that
/// measures the water, or the float switch. Pops with the chosen [Sensor].
class SensorPickerScreen extends ConsumerWidget {
  const SensorPickerScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.purpose = SensorPurpose.level,
    this.selectedId,
    this.excludedId,
  });

  final String deviceId;
  final String deviceName;
  final SensorPurpose purpose;
  final String? selectedId;

  /// Already in use for the other purpose, so not offered.
  final String? excludedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final provider = deviceSensorsProvider(deviceId);

    final isFloat = purpose == SensorPurpose.float;

    return AsyncListPage<Sensor>(
      title: isFloat ? 'Pilih sensor pelampung' : 'Pilih sensor',
      value: ref
          .watch(provider)
          .whenData(
            (sensors) => [
              for (final sensor in sensors)
                if (sensor.id != excludedId) sensor,
            ],
          ),
      onRefresh: () => ref.refresh(provider.future),
      emptyTitle: 'Belum ada sensor',
      emptyMessage: 'Tidak ada baris device_sensors untuk $deviceName.',
      builder: (context, sensors) => InsetSection(
        header: deviceName,
        footer: isFloat
            ? 'Perangkat mengirim 1 saat pelampung terangkat (penuh) dan 0 '
                  'saat turun. Pelampung yang terangkat membuat status Penuh.'
            : 'Arti nilai ditebak dari kolom unit dan nama sensor, '
                  'dan bisa diubah di Pengaturan.',
        children: [
          for (final sensor in sensors)
            InsetRow(
              leading: IconTile(
                icon: isFloat
                    ? CupertinoIcons.arrow_up_to_line
                    : CupertinoIcons.gauge,
                tone: isFloat || looksLikeLevelSensor(sensor)
                    ? palette.info
                    : palette.warning,
              ),
              title: sensor.name,
              subtitle: [
                if (sensor.unit != null) 'unit ${sensor.unit}',
                if (isFloat)
                  ?sensor.dataType
                else if (looksLikeLevelSensor(sensor))
                  Format.valueKind(inferValueKind(sensor))
                else
                  'bukan satuan ketinggian',
                ?sensor.pinConfig,
              ].join(' · '),
              trailing: sensor.id == selectedId
                  ? Icon(
                      CupertinoIcons.check_mark,
                      size: 20,
                      color: palette.accent,
                    )
                  : null,
              onTap: () => Navigator.of(context).pop(sensor),
            ),
        ],
      ),
    );
  }
}
