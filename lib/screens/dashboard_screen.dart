import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tank_config.dart';
import '../models/tank_level.dart';
import '../providers/config_provider.dart';
import '../providers/monitor_provider.dart';
import '../services/format.dart';
import '../services/tank_rules.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/app_primitives.dart';
import '../widgets/brand/water_header.dart';
import '../widgets/dashboard/level_chart.dart';
import '../widgets/dashboard/stat_tile.dart';
import '../widgets/dashboard/tank_gauge.dart';
import '../widgets/ios/app_toast.dart';
import '../widgets/ios/inset_section.dart';
import '../widgets/motion/reveal.dart';

/// The one screen the app is for: how much water is in the tank, and whether
/// that is about to become a problem.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final state = ref.watch(monitorProvider);
    final config = ref.watch(configProvider);

    // The system notification can be missed while the phone is in hand; the
    // toast says the same thing on the screen being looked at.
    ref.listen<AlertEntry?>(monitorProvider.select((s) => s.lastAlert), (
      previous,
      next,
    ) {
      if (next == null || identical(previous, next)) return;
      AppToast.show(
        context,
        Format.alertTitle(next.kind),
        icon: next.kind.level.icon,
      );
    });

    final sections = <Widget>[
      if (!config.hasSensor)
        _Banner(
          title: 'Sensor belum dipilih',
          message:
              'Buka tab Pengaturan, pilih perangkat dan sensor ketinggian, '
              'lalu tekan Simpan pengaturan.',
          icon: CupertinoIcons.gear,
          tone: palette.info,
        )
      else if (state.error != null)
        _Banner(
          title: state.showsLastKnown
              ? 'Menampilkan data terakhir'
              : 'Sensor tidak terhubung',
          message: state.error!,
          icon: CupertinoIcons.wifi_slash,
          tone: palette.danger,
          onRetry: () => ref.read(monitorProvider.notifier).refresh(),
        )
      else if (state.isOutdated && state.reading != null)
        _Banner(
          title: 'Perangkat tidak mengirim data',
          message:
              'Pembacaan terakhir ${Format.relative(state.reading!.measuredAt)}. '
              'Periksa daya dan Wi-Fi perangkat sensor.',
          icon: CupertinoIcons.clock,
          tone: palette.warning,
          onRetry: () => ref.read(monitorProvider.notifier).refresh(),
        ),
      _StatsGrid(state: state, config: config),
      InsetSection(
        header: 'Riwayat ketinggian',
        footer: state.history.isEmpty
            ? null
            : '${state.history.length} pembacaan terakhir, tiap ${config.pollSeconds} detik.',
        children: [
          InsetCustomRow(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: LevelChart(
              history: state.history,
              fullThreshold: config.fullThreshold,
              emptyThreshold: config.emptyThreshold,
            ),
          ),
        ],
      ),
      InsetSection(
        header: 'Ambang notifikasi',
        footer: config.notificationsEnabled
            ? 'Notifikasi dikirim sekali setiap kali air mencapai batas ini.'
            : 'Notifikasi sedang dimatikan di Pengaturan.',
        children: [
          InsetRow(
            leading: IconTile(icon: TankLevel.full.icon, tone: palette.info),
            title: 'Penuh',
            subtitle: 'Saat air ${config.fullThreshold}% ke atas',
            trailing: AppBadge(
              label: '${config.fullThreshold}%',
              tone: palette.info,
            ),
          ),
          InsetRow(
            leading: IconTile(icon: TankLevel.empty.icon, tone: palette.danger),
            title: 'Kosong',
            subtitle: 'Saat air ${config.emptyThreshold}% ke bawah',
            trailing: AppBadge(
              label: '${config.emptyThreshold}%',
              tone: palette.danger,
            ),
          ),
        ],
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status-bar icons over the navy header.
      value: SystemUiOverlayStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: palette.groupedBackground,
        child: Column(
          children: [
            _Hero(state: state, config: config),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () =>
                        ref.read(monitorProvider.notifier).refresh(),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverList.list(
                      children: [
                        for (var i = 0; i < sections.length; i++)
                          EnterReveal(
                            delay: AppMotion.stagger * (i + 1),
                            child: sections[i],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.state, required this.config});

  final MonitorState state;
  final TankConfig config;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onHero = palette.onHero;
    final reading = state.reading;

    return WaterHeader(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg + 4,
            AppSpacing.sm,
            AppSpacing.lg + 4,
            AppSpacing.xl + 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: onHero.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.drop_fill,
                      color: onHero,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GroundTank',
                          style: AppText.headline.copyWith(color: onHero),
                        ),
                        Text(
                          config.deviceName ?? 'Monitoring ketinggian air',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: onHero.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SourcePill(config: config, state: state),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TankGauge(
                    percent: reading?.percent,
                    fullThreshold: config.fullThreshold,
                    emptyThreshold: config.emptyThreshold,
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ketinggian air',
                          style: AppText.footnote.copyWith(
                            color: onHero.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (reading == null && state.isFetching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: CupertinoActivityIndicator(
                              color: Color(0xFFFFFFFF),
                              radius: 13,
                            ),
                          )
                        else
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              reading == null
                                  ? '--'
                                  : Format.percent(reading.percent),
                              style: AppText.display.copyWith(color: onHero),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        _LevelPill(level: state.level),
                        const SizedBox(height: AppSpacing.md),
                        if (reading != null) ...[
                          Text(
                            '${Format.cm(reading.levelCm)} dari ${Format.cm(config.tankHeightCm)}',
                            style: AppText.subhead.copyWith(color: onHero),
                          ),
                          const SizedBox(height: 2),
                          _Ticking(
                            builder: () =>
                                'Diperbarui ${Format.relative(reading.measuredAt)}',
                            style: AppText.caption.copyWith(
                              color: onHero.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the numbers are coming from, and whether they are current.
class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.config, required this.state});

  final TankConfig config;
  final MonitorState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (String label, Color dot) = switch (state.error) {
      _ when !config.hasSensor => (
        'Belum diatur',
        palette.onHero.withValues(alpha: 0.5),
      ),
      null when state.isOutdated => ('Tidak aktif', palette.warning.foreground),
      null when state.reading != null => ('Live', palette.success.foreground),
      null => ('Menghubungkan', const Color(0xFFFFFFFF)),
      _ => ('Offline', palette.danger.foreground),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.onHero.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.caption.copyWith(
              color: palette.onHero,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});

  final TankLevel? level;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tone = level.tone(palette);
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      child: Container(
        key: ValueKey(level),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(level.icon, size: 14, color: tone.foreground),
            const SizedBox(width: 5),
            Text(
              Format.levelLabel(level),
              style: AppText.caption.copyWith(
                color: tone.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.state, required this.config});

  final MonitorState state;
  final TankConfig config;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reading = state.reading;
    final neutral = ToneColors(
      foreground: palette.accent,
      background: palette.accentTint,
      onBackground: palette.accent,
    );

    final trend = trendOf(state.history);
    final (
      String trendValue,
      IconData trendIcon,
      ToneColors trendTone,
    ) = switch (trend?.direction) {
      TrendDirection.filling => (
        'Mengisi',
        CupertinoIcons.arrow_up_right,
        palette.success,
      ),
      TrendDirection.draining => (
        'Berkurang',
        CupertinoIcons.arrow_down_right,
        palette.warning,
      ),
      TrendDirection.steady => ('Stabil', CupertinoIcons.minus, neutral),
      null => ('Menghitung…', CupertinoIcons.waveform_path, neutral),
    };
    String? trendCaption;
    if (trend != null && reading != null) {
      final eta = minutesToThreshold(reading.percent, trend, config);
      final rate = '${Format.signed(trend.percentPerMinute)}%/mnt';
      trendCaption = switch ((trend.direction, eta)) {
        (TrendDirection.filling, final m?) =>
          '$rate · penuh ${Format.duration(m)}',
        (TrendDirection.draining, final m?) =>
          '$rate · kosong ${Format.duration(m)}',
        _ => rate,
      };
    }

    Widget row(Widget a, Widget b) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: a),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: b),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: [
          row(
            StatTile(
              icon: CupertinoIcons.drop,
              tone: palette.info,
              label: 'Volume air',
              value: reading == null
                  ? '--'
                  : Format.liters(reading.volumeLiters),
              caption: 'dari ${Format.liters(config.capacityLiters)}',
            ),
            StatTile(
              icon: CupertinoIcons.arrow_up_arrow_down,
              tone: neutral,
              label: 'Ketinggian',
              value: reading == null ? '--' : Format.cmPrecise(reading.levelCm),
              caption: 'maks ${Format.cmCompact(config.tankHeightCm)}',
            ),
          ),
          row(
            StatTile(
              icon: CupertinoIcons.cube,
              tone: neutral,
              label: 'Ruang kosong',
              value: reading == null
                  ? '--'
                  : Format.liters(config.capacityLiters - reading.volumeLiters),
              caption: reading == null
                  ? null
                  : '${Format.percent(100 - reading.percent)} belum terisi',
            ),
            StatTile(
              icon: trendIcon,
              tone: trendTone,
              label: 'Tren',
              value: trendValue,
              caption: trendCaption,
            ),
          ),
        ],
      ),
    );
  }
}

/// A problem with the data, above the figures it affects.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    required this.message,
    required this.icon,
    required this.tone,
    this.onRetry,
  });

  final String title;
  final String message;
  final IconData icon;
  final ToneColors tone;

  /// Null when retrying cannot help, e.g. nothing is set up yet.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone.foreground, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.subhead.copyWith(
                    color: tone.onBackground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppText.footnote.copyWith(color: tone.onBackground),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(44, 44),
              onPressed: onRetry,
              child: Text(
                'Coba lagi',
                style: AppText.footnote.copyWith(
                  color: tone.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// A line of text rebuilt every second, for "Diperbarui 12 dtk lalu".
class _Ticking extends StatefulWidget {
  const _Ticking({required this.builder, required this.style});

  final String Function() builder;
  final TextStyle style;

  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking> {
  late final Timer _timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(widget.builder(), style: widget.style);
}
