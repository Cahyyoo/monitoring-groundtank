import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tank_level.dart';
import '../services/settings_service.dart';

class AlertsState {
  const AlertsState({this.entries = const [], this.seenAt});

  /// Newest first.
  final List<AlertEntry> entries;

  /// When the Notifikasi tab was last opened.
  final DateTime? seenAt;

  int get unread =>
      entries.where((e) => seenAt == null || e.at.isAfter(seenAt!)).length;
}

/// The log behind the Notifikasi tab.
///
/// Written by [TankEvaluator] from either isolate, so it is re-read rather
/// than kept in step by hand: after each alert the dashboard raises, and
/// whenever the app returns to the foreground.
class AlertsNotifier extends StateNotifier<AlertsState> {
  AlertsNotifier() : super(const AlertsState()) {
    reload();
  }

  Future<void> reload() async {
    try {
      final entries = await SettingsService.getAlerts();
      final seenAt = await SettingsService.getAlertsSeenAt();
      if (mounted) state = AlertsState(entries: entries, seenAt: seenAt);
    } catch (_) {}
  }

  Future<void> markSeen() async {
    final now = DateTime.now();
    state = AlertsState(entries: state.entries, seenAt: now);
    await SettingsService.setAlertsSeenAt(now);
  }

  Future<void> clear() async {
    await SettingsService.clearAlerts();
    state = AlertsState(seenAt: state.seenAt);
  }
}

final alertsProvider = StateNotifierProvider<AlertsNotifier, AlertsState>((
  ref,
) {
  return AlertsNotifier();
});
