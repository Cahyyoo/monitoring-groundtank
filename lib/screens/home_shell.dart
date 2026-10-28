import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/alerts_provider.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

enum _Tab { dashboard, alerts, settings }

const double _barHeight = 60;

/// Three destinations under Atara's bottom bar: the current one a filled
/// accent icon over an accent label, the rest outlined grey.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  _Tab _tab = _Tab.dashboard;

  /// Tabs are built the first time they are opened, not all at launch.
  final Set<_Tab> _visited = {_Tab.dashboard};

  void _select(_Tab tab) {
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
    if (tab == _Tab.alerts) ref.read(alertsProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unread = ref.watch(alertsProvider.select((s) => s.unread));

    // An alert arriving while its list is on screen has been seen.
    ref.listen<int>(alertsProvider.select((s) => s.unread), (_, next) {
      if (next > 0 && _tab == _Tab.alerts) {
        ref.read(alertsProvider.notifier).markSeen();
      }
    });

    Widget page(_Tab tab) {
      if (!_visited.contains(tab)) return const SizedBox.shrink();
      return switch (tab) {
        _Tab.dashboard => const DashboardScreen(),
        _Tab.alerts => const AlertsScreen(),
        _Tab.settings => const SettingsScreen(),
      };
    }

    // The keyboard covers the tab bar instead of lifting it over the field
    // being typed in, and each page's own scaffold makes room for it — less
    // the bar it already sits above, or a bar-high gap opens over the keys.
    final media = MediaQuery.of(context);
    final barHeight = _barHeight + media.padding.bottom;
    final pageMedia = media.copyWith(
      viewInsets: media.viewInsets.copyWith(
        bottom: (media.viewInsets.bottom - barHeight).clamp(0, double.infinity),
      ),
    );

    return CupertinoPageScaffold(
      backgroundColor: palette.groupedBackground,
      resizeToAvoidBottomInset: false,
      child: Column(
        children: [
          Expanded(
            child: MediaQuery(
              data: pageMedia,
              child: IndexedStack(
                index: _tab.index,
                children: [
                  for (final tab in _Tab.values)
                    // Hidden tabs keep their state but may not animate or fly a
                    // Hero into a pushed route.
                    HeroMode(
                      enabled: tab == _tab,
                      child: TickerMode(enabled: tab == _tab, child: page(tab)),
                    ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.cardBackground,
              border: Border(
                top: BorderSide(color: palette.separator, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: _barHeight,
                child: Row(
                  children: [
                    _TabItem(
                      icon: CupertinoIcons.gauge,
                      activeIcon: CupertinoIcons.gauge,
                      label: 'Dashboard',
                      active: _tab == _Tab.dashboard,
                      onTap: () => _select(_Tab.dashboard),
                    ),
                    _TabItem(
                      icon: CupertinoIcons.bell,
                      activeIcon: CupertinoIcons.bell_fill,
                      label: 'Notifikasi',
                      active: _tab == _Tab.alerts,
                      badge: _tab == _Tab.alerts ? 0 : unread,
                      onTap: () => _select(_Tab.alerts),
                    ),
                    _TabItem(
                      icon: CupertinoIcons.gear,
                      activeIcon: CupertinoIcons.gear_solid,
                      label: 'Pengaturan',
                      active: _tab == _Tab.settings,
                      onTap: () => _select(_Tab.settings),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? palette.accent : palette.secondaryLabel;

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: badge > 0 ? '$label, $badge baru' : label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.fast,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.8,
                        end: 1,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      active ? activeIcon : icon,
                      key: ValueKey(active),
                      size: 24,
                      color: color,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -10,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.danger.foreground,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: palette.cardBackground,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: AppText.caption.copyWith(
                            fontSize: 9.5,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: AppMotion.fast,
                style: AppText.caption.copyWith(
                  fontSize: 11,
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
