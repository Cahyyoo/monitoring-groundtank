import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/env.dart';
import '../models/tank_config.dart';
import '../services/settings_service.dart';
import '../services/tank_evaluator.dart';
import '../services/tank_repository.dart';
import '../services/tank_source.dart';

const _uniqueName = 'groundtank-periodic-check';
const _taskName = 'groundtank.check';

/// Runs in its own isolate whenever Android's WorkManager decides the
/// periodic check is due — at best every 15 minutes, later when the phone is
/// dozing. Must stay a top-level function marked as an entry point, or the
/// release compiler strips it.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    SupabaseClient? client;
    try {
      final config = await SettingsService.loadConfig();
      if (!config.backgroundEnabled) return true;
      // A bare client rather than Supabase.initialize: this isolate needs one
      // query, not a persisted auth session or lifecycle handling.
      if (!config.isDemo && Env.isSupabaseConfigured) {
        client = SupabaseClient(
          Env.supabaseUrl,
          Env.supabaseKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
      }
      final source = TankSource.forConfig(
        config,
        repository: client == null ? null : TankRepository(client),
      );
      await TankEvaluator.evaluate(await source.fetch(), config);
    } catch (e) {
      // A sensor that is unreachable now will be asked again next period;
      // reporting failure would only make WorkManager retry sooner and drain
      // the battery on a device that is simply switched off.
      debugPrint('Background check failed: $e');
    } finally {
      await client?.dispose();
    }
    return true;
  });
}

/// Keeps the scheduled background check in line with the configuration.
///
/// Android only. iOS gives no dependable periodic slot to an app like this —
/// there the notifications come from the dashboard while it is open.
class BackgroundMonitor {
  static bool _initialised = false;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<void> sync(TankConfig config) async {
    if (!isSupported) return;
    try {
      if (!_initialised) {
        await Workmanager().initialize(backgroundDispatcher);
        _initialised = true;
      }
      if (!config.backgroundEnabled) {
        await Workmanager().cancelByUniqueName(_uniqueName);
        return;
      }
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: const Duration(minutes: 15),
        // `update` so a changed source takes effect without waiting out the
        // old schedule.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          networkType: config.isDemo
              ? NetworkType.notRequired
              : NetworkType.connected,
        ),
      );
    } catch (e) {
      debugPrint('Could not schedule background check: $e');
    }
  }
}
