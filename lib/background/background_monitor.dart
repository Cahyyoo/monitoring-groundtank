import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';
import 'package:workmanager/workmanager.dart';

import '../config/env.dart';
import '../models/tank_config.dart';
import '../services/settings_service.dart';
import '../services/tank_evaluator.dart';
import '../services/tank_repository.dart';
import '../services/tank_rules.dart';
import '../services/tank_source.dart';

const _uniqueName = 'groundtank-periodic-check';
const _taskName = 'groundtank.check';

/// Android's minimum for periodic work.
const _period = Duration(minutes: 15);

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
      var config = await SettingsService.loadConfig();
      if (!_shouldRun(config) || !Env.isSupabaseConfigured) return true;
      // Its own client: this isolate shares no memory with the app's.
      client = Env.createSupabaseClient();
      final repository = TankRepository(client);
      // A phone left closed for days must still follow the shared settings;
      // when they cannot be fetched, the cached copy is the next best.
      try {
        final shared = await repository.fetchSharedSettings();
        if (shared != null) {
          final next = shared.applyTo(config);
          if (next != config) {
            await SettingsService.saveConfig(next);
            if (judgesDifferently(config, next)) {
              await SettingsService.clearLastLevel();
            }
            config = next;
          }
        }
      } on TankSourceException catch (e) {
        debugPrint('Shared settings unavailable: $e');
      }
      final source = TankSource.forConfig(config, repository: repository);
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

/// Whether there is a sensor to check and the user wants it checked.
bool _shouldRun(TankConfig config) =>
    config.backgroundEnabled && config.hasSensor;

/// Keeps the scheduled background check in line with the configuration.
///
/// Android only. iOS gives no dependable periodic slot to an app like this —
/// there the notifications come from the dashboard while it is open.
class BackgroundMonitor {
  static bool _initialised = false;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// A platform call that has not answered by then is not coming back soon.
  static const _callTimeout = Duration(seconds: 10);

  static Future<void> sync(TankConfig config) async {
    if (!isSupported) return;
    try {
      if (!_initialised) {
        await Workmanager()
            .initialize(backgroundDispatcher)
            .timeout(_callTimeout);
        _initialised = true;
      }
      if (!_shouldRun(config)) {
        await Workmanager()
            .cancelByUniqueName(_uniqueName)
            .timeout(_callTimeout);
        return;
      }
      await Workmanager()
          .registerPeriodicTask(
            _uniqueName,
            _taskName,
            frequency: _period,
            // Without a delay the first run starts at once, booting a second
            // Flutter engine on the main thread while the dashboard, which
            // polls by itself, is in use.
            initialDelay: _period,
            // `keep` so the sync at every launch does not restart the clock.
            // The worker reads the saved configuration on each run, so a new
            // sensor or threshold needs no re-registration.
            existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
            constraints: Constraints(networkType: NetworkType.connected),
          )
          .timeout(_callTimeout);
    } catch (e) {
      debugPrint('Could not schedule background check: $e');
    }
  }
}
