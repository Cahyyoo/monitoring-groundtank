import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../background/background_monitor.dart';
import '../models/shared_settings.dart';
import '../models/tank_config.dart';
import '../services/settings_service.dart';
import '../services/tank_rules.dart';

/// The configuration in effect: the shared tank settings as last received,
/// with this phone's own choices.
///
/// Read once in `main` before the first frame and handed in through an
/// override, so no screen ever has to render a "configuration loading" state.
/// Kept on the phone whole, so it also works offline and in the background
/// isolate; `sharedSettingsProvider` keeps the shared part current.
class ConfigNotifier extends StateNotifier<TankConfig> {
  ConfigNotifier(super.initial);

  /// Applies [next] as a whole, whatever part of it changed.
  Future<void> save(TankConfig next) async {
    final previous = state;
    if (next == previous) return;
    await SettingsService.saveConfig(next);
    if (judgesDifferently(previous, next)) {
      await SettingsService.clearLastLevel();
    }
    state = next;
    // The worker reads the saved configuration on every run, so only turning
    // it on or off needs the schedule touched. Not awaited: a slow platform
    // call must not keep the Save button spinning.
    if (previous.backgroundEnabled != next.backgroundEnabled ||
        previous.hasSensor != next.hasSensor) {
      unawaited(BackgroundMonitor.sync(next));
    }
  }

  /// This phone's own choices from [draft]; the shared part is left alone.
  Future<void> saveLocal(TankConfig draft) => save(
    state.copyWith(
      pollSeconds: draft.pollSeconds,
      notificationsEnabled: draft.notificationsEnabled,
      backgroundEnabled: draft.backgroundEnabled,
    ),
  );

  /// The shared settings as received from Supabase.
  Future<void> applyShared(SharedSettings shared) =>
      save(shared.applyTo(state));
}

final configProvider = StateNotifierProvider<ConfigNotifier, TankConfig>((ref) {
  return ConfigNotifier(const TankConfig());
});
