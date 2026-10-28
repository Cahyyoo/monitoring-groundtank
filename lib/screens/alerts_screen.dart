import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tank_level.dart';
import '../providers/alerts_provider.dart';
import '../services/format.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_primitives.dart';
import '../widgets/ios/app_page.dart';
import '../widgets/ios/inset_section.dart';

/// Whether the system will actually show our notifications. Null when the
/// platform cannot say.
final notificationsAllowedProvider = FutureProvider.autoDispose<bool?>((ref) {
  return NotificationService.areEnabled();
});

/// Every time the tank became full or empty, newest first, grouped by day.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Hapus semua riwayat notifikasi?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
      ),
    );
    if (confirmed == true) await ref.read(alertsProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final alerts = ref.watch(alertsProvider);
    final allowed = ref.watch(notificationsAllowedProvider).valueOrNull;

    final children = <Widget>[
      if (allowed == false)
        InsetSection(
          footer:
              'Tanpa izin, peringatan penuh/kosong hanya tercatat di sini '
              'dan tidak muncul di layar kunci.',
          children: [
            InsetRow(
              leading: IconTile(
                icon: CupertinoIcons.bell_slash,
                tone: palette.warning,
              ),
              title: 'Izin notifikasi nonaktif',
              subtitle: 'Ketuk untuk mengizinkan',
              showChevron: true,
              onTap: () async {
                await NotificationService.requestPermission();
                ref.invalidate(notificationsAllowedProvider);
              },
            ),
          ],
        ),
      if (alerts.entries.isEmpty)
        const _EmptyState()
      else
        for (final group in _byDay(alerts.entries))
          InsetSection(
            header: group.$1,
            children: [
              for (final entry in group.$2)
                InsetRow(
                  leading: IconTile(
                    icon: entry.kind.level.icon,
                    tone: entry.kind.level.tone(palette),
                  ),
                  title: Format.alertTitle(entry.kind),
                  subtitle:
                      'Air ${Format.percent(entry.percent)} · pukul ${Format.clock(entry.at)}',
                ),
            ],
          ),
    ];

    return AppPage.list(
      title: 'Notifikasi',
      trailing: alerts.entries.isEmpty
          ? null
          : NavBarAction(
              label: 'Hapus',
              isDestructive: true,
              onPressed: () => _confirmClear(context, ref),
            ),
      onRefresh: () async {
        ref.invalidate(notificationsAllowedProvider);
        await ref.read(alertsProvider.notifier).reload();
      },
      children: children,
    );
  }

  static List<(String, List<AlertEntry>)> _byDay(List<AlertEntry> entries) {
    final today = DateUtils.dateOnly(DateTime.now());
    final groups = <(String, List<AlertEntry>)>[];
    DateTime? current;
    for (final entry in entries) {
      final day = DateUtils.dateOnly(entry.at);
      if (day != current) {
        current = day;
        final label = switch (today.difference(day).inDays) {
          0 => 'Hari ini',
          1 => 'Kemarin',
          _ => Format.dateTime(day).split(',').first,
        };
        groups.add((label, []));
      }
      groups.last.$2.add(entry);
    }
    return groups;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl * 2),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: palette.accentTint,
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.bell, size: 38, color: palette.accent),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Belum ada notifikasi',
            style: AppText.headline.copyWith(color: palette.label),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              'Peringatan akan muncul di sini saat air di ground tank penuh atau kosong.',
              textAlign: TextAlign.center,
              style: AppText.footnote.copyWith(color: palette.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}
