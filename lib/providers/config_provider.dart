import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../background/background_monitor.dart';
import '../models/tank_config.dart';
import '../services/settings_service.dart';

/// The saved configuration.
///
/// Read once in `main` before the first frame and handed in through an
/// override, so no screen ever has to render a "configuration loading" state.
class ConfigNotifier extends StateNotifier<TankConfig> {
  ConfigNotifier(super.initial);

  Future<void> save(TankConfig next) async {
    final previous = state;
    await SettingsService.saveConfig(next);
    // A different tank, sensor or threshold makes the remembered state
    // meaningless; judge the next reading afresh so a tank that is already
    // full is announced under the new settings.
    if (previous.sourceKey != next.sourceKey ||
        previous.valueKind != next.valueKind ||
        previous.fullThreshold != next.fullThreshold ||
        previous.emptyThreshold != next.emptyThreshold) {
      await SettingsService.clearLastLevel();
    }
    state = next;
    await BackgroundMonitor.sync(next);
  }
}

final configProvider = StateNotifierProvider<ConfigNotifier, TankConfig>((ref) {
  return ConfigNotifier(const TankConfig());
});
