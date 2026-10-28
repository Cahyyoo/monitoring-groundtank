import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../providers/database_providers.dart';
import '../services/format.dart';
import '../theme/app_theme.dart';
import '../widgets/app_primitives.dart';
import '../widgets/ios/async_list_page.dart';
import '../widgets/ios/inset_section.dart';

/// Every row of `devices`, to choose the tank's controller. Pops with the
/// chosen [Device].
class DevicePickerScreen extends ConsumerWidget {
  const DevicePickerScreen({super.key, this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return AsyncListPage<Device>(
      title: 'Pilih perangkat',
      value: ref.watch(devicesProvider),
      onRefresh: () => ref.refresh(devicesProvider.future),
      emptyTitle: 'Belum ada perangkat',
      emptyMessage:
          'Tabel devices kosong, atau kebijakan RLS belum mengizinkan '
          'aplikasi membacanya (lihat supabase/setup.sql).',
      builder: (context, devices) => InsetSection(
        footer: 'Status diambil dari kolom status pada tabel devices.',
        children: [
          for (final device in devices)
            InsetRow(
              leading: IconTile(
                icon: CupertinoIcons.antenna_radiowaves_left_right,
                tone: device.isActive ? palette.success : palette.danger,
              ),
              title: device.name,
              subtitle: [
                ?device.project,
                ?device.ipAddress,
                if (device.updatedAt != null)
                  'diperbarui ${Format.relative(device.updatedAt!)}',
              ].join(' · '),
              trailing: device.id == selectedId
                  ? Icon(
                      CupertinoIcons.check_mark,
                      size: 20,
                      color: palette.accent,
                    )
                  : AppBadge(
                      label: device.isActive ? 'Aktif' : 'Nonaktif',
                      tone: device.isActive ? palette.success : palette.danger,
                    ),
              onTap: () => Navigator.of(context).pop(device),
            ),
        ],
      ),
    );
  }
}
