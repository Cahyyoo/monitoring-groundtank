import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'background/background_monitor.dart';
import 'config/env.dart';
import 'models/tank_config.dart';
import 'providers/alerts_provider.dart';
import 'providers/config_provider.dart';
import 'providers/monitor_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Two small reads before the first frame, so no screen ever has to draw a
  // "configuration loading" state: Indonesian month names and the saved tank.
  await initializeDateFormatting('id');
  final config = await SettingsService.loadConfig();
  await _initSupabase();

  runApp(
    ProviderScope(
      overrides: [configProvider.overrideWith((ref) => ConfigNotifier(config))],
      child: const GroundTankApp(),
    ),
  );

  unawaited(_startServices(config));
}

/// Only when this build carries keys (`--dart-define-from-file=env.json`).
/// A failure leaves `supabaseClientProvider` reading as null, and the
/// dashboard and Settings explain why there is no data.
Future<void> _initSupabase() async {
  if (!Env.isSupabaseConfigured) return;
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );
  } catch (e) {
    debugPrint('Supabase unavailable: $e');
  }
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
  const GroundTankApp({super.key});

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
        child: child!,
      ),
      home: const MonitorScope(child: HomeShell()),
    );
  }
}

/// Starts and stops polling with the app's lifecycle, and fetches at once when
/// the connection comes back.
class MonitorScope extends ConsumerStatefulWidget {
  const MonitorScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MonitorScope> createState() => _MonitorScopeState();
}

class _MonitorScopeState extends ConsumerState<MonitorScope>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Built here so polling starts with the first frame.
    ref.read(monitorProvider);
    try {
      _connectivity = Connectivity().onConnectivityChanged.listen((results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          ref.read(monitorProvider.notifier).refresh();
        }
      });
    } catch (_) {
      // No connectivity channel (tests, unsupported platform): the timer and
      // pull-to-refresh still cover it.
    }
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
        // The background check may have logged alerts while we were away.
        ref.read(alertsProvider.notifier).reload();
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
