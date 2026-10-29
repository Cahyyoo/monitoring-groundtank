import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tank_config.dart';
import '../models/tank_level.dart';
import '../models/tank_reading.dart';
import '../services/tank_evaluator.dart';
import '../services/tank_rules.dart';
import '../services/tank_source.dart';
import 'alerts_provider.dart';
import 'config_provider.dart';
import 'database_providers.dart';

/// Where readings come from right now. Overridden in tests.
final tankSourceProvider = Provider<TankSource>((ref) {
  return TankSource.forConfig(
    ref.watch(configProvider),
    repository: ref.watch(tankRepositoryProvider),
  );
});

class MonitorState {
  const MonitorState({
    this.reading,
    this.level,
    this.error,
    this.isFetching = false,
    this.isOutdated = false,
    this.history = const [],
    this.lastAlert,
  });

  /// The newest good reading. Kept while later fetches fail, so a dropped
  /// connection shows the last known level with a warning rather than a blank.
  final TankReading? reading;

  final TankLevel? level;

  /// Why the most recent fetch failed; null once one succeeds again.
  final String? error;

  final bool isFetching;

  /// The newest reading is older than the device should allow: it has
  /// probably stopped sending. See [isStale].
  final bool isOutdated;

  /// Oldest first, capped at [MonitorNotifier.historyLimit].
  final List<TankReading> history;

  /// The alert the latest reading raised, for the in-app toast.
  final AlertEntry? lastAlert;

  bool get showsLastKnown => error != null && reading != null;

  MonitorState copyWith({
    TankReading? reading,
    TankLevel? level,
    String? Function()? error,
    bool? isFetching,
    bool? isOutdated,
    List<TankReading>? history,
    AlertEntry? Function()? lastAlert,
  }) {
    return MonitorState(
      reading: reading ?? this.reading,
      level: level ?? this.level,
      error: error != null ? error() : this.error,
      isFetching: isFetching ?? this.isFetching,
      isOutdated: isOutdated ?? this.isOutdated,
      history: history ?? this.history,
      lastAlert: lastAlert != null ? lastAlert() : this.lastAlert,
    );
  }
}

/// Watches the tank while the app is in front of someone.
///
/// On start it fills the chart from [TankSource.recent], then listens to
/// [TankSource.watch] for pushed readings (Supabase Realtime) and polls every
/// `pollSeconds` as a safety net — Realtime may be off for the table, or the
/// socket may have dropped without saying so.
///
/// Stops in the background on purpose — the WorkManager check covers that
/// case at a pace the battery can afford — and starts afresh on return, so
/// readings missed meanwhile are back-filled into the chart.
class MonitorNotifier extends StateNotifier<MonitorState> {
  MonitorNotifier(this._ref) : super(const MonitorState()) {
    // Any change can alter what a reading means (another device, another
    // unit, other dimensions), so the history is rebuilt rather than mixed.
    _ref.listen<TankConfig>(configProvider, (_, _) => _start());
    _start();
  }

  final Ref _ref;

  static const historyLimit = 120;

  Timer? _timer;
  StreamSubscription<TankReading>? _subscription;
  bool _foreground = true;
  Future<void>? _inFlight;

  /// Bumped by every [_start]; work begun under an older value is discarded
  /// when it completes, so a slow history load cannot land on a new source.
  int _generation = 0;

  set foreground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    value ? _start() : _stop();
  }

  TankConfig get _config => _ref.read(configProvider);

  void _stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  Future<void> _start() async {
    _stop();
    if (!_foreground || !mounted) return;
    final generation = _generation;
    final source = _ref.read(tankSourceProvider);
    final config = _config;
    // Nothing to read until a sensor is chosen; the dashboard says so.
    if (!config.hasSensor) {
      state = MonitorState(lastAlert: state.lastAlert);
      return;
    }
    state = MonitorState(lastAlert: state.lastAlert, isFetching: true);

    try {
      final window = Duration(
        seconds: (config.pollSeconds * historyLimit).clamp(60, 3600),
      );
      final history = await source.recent(window);
      if (generation != _generation || !mounted) return;
      if (history.isNotEmpty) {
        state = state.copyWith(history: history.sublist(0, history.length - 1));
        await _accept(history.last, generation);
      }
    } catch (_) {
      // The chart starting empty is not worth an error; the fetch below
      // reports a real connection problem in its own words.
    }
    if (generation != _generation || !mounted) return;

    _subscription = source.watch()?.listen(
      (reading) => _accept(reading, generation),
      onError: (Object _) {}, // Polling carries on regardless.
    );
    final seconds = config.pollSeconds.clamp(2, 3600);
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => refresh());
    await refresh();
  }

  /// One fetch now. A call while one is already running joins it rather than
  /// starting a second, so a pull-to-refresh during a tick does not double up.
  Future<void> refresh() => _inFlight ??= _fetch().whenComplete(() {
    _inFlight = null;
  });

  Future<void> _fetch() async {
    if (!mounted || !_config.hasSensor) return;
    final generation = _generation;
    state = state.copyWith(isFetching: true);
    try {
      final reading = await _ref.read(tankSourceProvider).fetch();
      await _accept(reading, generation);
    } catch (e) {
      if (generation != _generation || !mounted) return;
      state = state.copyWith(
        error: () =>
            e is TankSourceException ? e.message : 'Gagal membaca sensor: $e',
        isFetching: false,
      );
    }
  }

  /// Takes in one reading from any path: history, push, or poll.
  Future<void> _accept(TankReading reading, int generation) async {
    if (generation != _generation || !mounted) return;
    final config = _config;
    final outdated = isStale(
      reading.measuredAt,
      pollSeconds: config.pollSeconds,
    );
    final last = state.history.lastOrNull;

    // The same row seen again — a poll after a push, or a device that has
    // gone quiet. Only the freshness can have changed.
    if (last != null && !reading.measuredAt.isAfter(last.measuredAt)) {
      state = state.copyWith(
        reading: state.reading ?? last,
        error: () => null,
        isFetching: false,
        isOutdated: isStale(last.measuredAt, pollSeconds: config.pollSeconds),
      );
      return;
    }

    final evaluation = await TankEvaluator.evaluate(reading, config);
    if (generation != _generation || !mounted) return;

    final history = [...state.history, reading];
    if (history.length > historyLimit) {
      history.removeRange(0, history.length - historyLimit);
    }
    state = state.copyWith(
      reading: reading,
      level: evaluation.level,
      error: () => null,
      isFetching: false,
      isOutdated: outdated,
      history: history,
      lastAlert: () => evaluation.alert ?? state.lastAlert,
    );
    if (evaluation.alert != null) {
      unawaited(_ref.read(alertsProvider.notifier).reload());
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

final monitorProvider = StateNotifierProvider<MonitorNotifier, MonitorState>((
  ref,
) {
  return MonitorNotifier(ref);
});
