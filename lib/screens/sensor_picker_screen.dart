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

/// The sensors wired to one device (`device_sensors`), to choose the one that
/// measures the water. Pops with the chosen [Sensor].
class SensorPickerScreen extends ConsumerWidget {
  const SensorPickerScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.selectedId,
  });

  final String deviceId;
  final String deviceName;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final provider = deviceSensorsProvider(deviceId);

    return AsyncListPage<Sensor>(
      title: 'Pilih sensor',
      value: ref.watch(provider),
      onRefresh: () => ref.refresh(provider.future),
      emptyTitle: 'Belum ada sensor',
      emptyMessage: 'Tidak ada baris device_sensors untuk $deviceName.',
      builder: (context, sensors) => InsetSection(
        header: deviceName,
        footer:
            'Arti nilai ditebak dari kolom unit dan nama sensor, '
            'dan bisa diubah di Pengaturan.',
        children: [
          for (final sensor in sensors)
            InsetRow(
              leading: IconTile(
                icon: CupertinoIcons.gauge,
                tone: looksLikeLevelSensor(sensor)
                    ? palette.info
                    : palette.warning,
              ),
              title: sensor.name,
              subtitle: [
                if (sensor.unit != null) 'unit ${sensor.unit}',
                if (looksLikeLevelSensor(sensor))
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
