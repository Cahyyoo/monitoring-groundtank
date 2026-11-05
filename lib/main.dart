import 'dart:async';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'background/background_monitor.dart';
import 'models/tank_config.dart';
import 'providers/alerts_provider.dart';
import 'providers/chart_provider.dart';
import 'providers/config_provider.dart';
import 'providers/monitor_provider.dart';
import 'providers/shared_settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';
import 'widgets/brand/app_splash.dart';
import 'widgets/update_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Two small reads before the first frame, so no screen ever has to draw a
  // "configuration loading" state: Indonesian month names and the saved tank.
  await initializeDateFormatting('id');
  final config = await SettingsService.loadConfig();

  runApp(
    ProviderScope(
      overrides: [configProvider.overrideWith((ref) => ConfigNotifier(config))],
      child: const GroundTankApp(showSplash: true),
    ),
  );

  unawaited(_startServices(config));
}

Future<void> _startServices(TankConfig config) async {
  await NotificationService.init();
  // Asked at launch: notifications are half of what this app is for.
  if (config.notificationsEnabled) {
    await NotificationService.requestPermission();
  }
  await BackgroundMonitor.sync(config);
}

class GroundTankApp extends ConsumerWidget {
  const GroundTankApp({super.key, this.showSplash = false});

  /// Whether a launch of the app opens with the splash.
  final bool showSplash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A MaterialApp hosting an entirely Cupertino interface, as in Atara: the
    // Material host keeps the Overlay and transition machinery, every screen
    // is built from Cupertino widgets.
    return MaterialApp(
      title: 'GroundTank',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      // CupertinoPageScaffold installs no ambient text style, so without this
      // every Text falls back to the framework's yellow-underlined error style.
      builder: (context, child) => DefaultTextStyle(
        style: AppText.body.copyWith(
          color: context.palette.label,
          decoration: TextDecoration.none,
        ),
        child: showSplash ? SplashOverlay(child: child!) : child!,
      ),
      home: const MonitorScope(child: HomeShell()),
    );
  }
}

/// Starts and stops polling with the app's lifecycle, and fetches at once when
/// the connection comes back. Keeps the shared tank settings current too.
class MonitorScope extends ConsumerStatefulWidget {
  const MonitorScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MonitorScope> createState() => _MonitorScopeState();
}

class _MonitorScopeState extends ConsumerState<MonitorScope>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  DateTime? _lastUpdateCheck;
  bool _updateDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
    // Built here so polling and the settings sync start with the first frame.
    ref.read(monitorProvider);
    ref.read(sharedSettingsProvider);
    try {
      _connectivity = Connectivity().onConnectivityChanged.listen((results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          ref.read(sharedSettingsProvider.notifier).refresh();
          ref.read(monitorProvider.notifier).refresh();
          ref.invalidate(chartReadingsProvider);
        }
      });
    } catch (_) {
      // No connectivity channel (tests, unsupported platform): the timer and
      // pull-to-refresh still cover it.
    }
  }

  /// On launch, and again on return if the app has stayed open for long: a
  /// monitoring app may not be closed for weeks. Release builds on Android
  /// only; a debug build could not install a differently signed APK anyway.
  Future<void> _checkForUpdate() async {
    if (!kReleaseMode || !Platform.isAndroid || _updateDialogOpen) return;
    final now = DateTime.now();
    final last = _lastUpdateCheck;
    if (last != null && now.difference(last) < const Duration(hours: 12)) {
      return;
    }
    _lastUpdateCheck = now;

    final info = await PackageInfo.fromPlatform();
    final release = await fetchNewerRelease(info.version);
    if (release == null || !mounted || _updateDialogOpen) return;
    _updateDialogOpen = true;
    await showUpdateDialog(context, release);
    _updateDialogOpen = false;
  }

  @override
  void dispose() {
    _connectivity?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final monitor = ref.read(monitorProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        monitor.foreground = true;
        // The background check may have logged alerts while we were away,
        // and another phone may have changed the shared settings.
        ref.read(alertsProvider.notifier).reload();
        ref.read(sharedSettingsProvider.notifier).refresh();
        ref.invalidate(chartReadingsProvider);
        _checkForUpdate();
      case AppLifecycleState.inactive:
        // A notification shade over a screen that is still showing.
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        monitor.foreground = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
