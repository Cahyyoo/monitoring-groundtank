import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shared_settings.dart';
import '../models/tank_config.dart';
import '../services/tank_repository.dart';
import '../services/tank_source.dart';
import 'config_provider.dart';
import 'database_providers.dart';

class SharedSettingsState {
  const SharedSettingsState({
    this.isLoading = false,
    this.exists = false,
    this.updatedAt,
    this.error,
  });

  final bool isLoading;

  /// Whether an admin has saved shared settings yet. Until then each phone
  /// keeps whatever it had.
  final bool exists;

  final DateTime? updatedAt;

  /// Why the last fetch failed; the phone carries on with its cached copy.
  final String? error;
}

/// Keeps the shared tank settings on this phone current: fetched on start
/// and on every return to the app, and pushed through Realtime meanwhile.
class SharedSettingsNotifier extends StateNotifier<SharedSettingsState> {
  SharedSettingsNotifier(this._ref) : super(const SharedSettingsState()) {
    final repository = _ref.read(tankRepositoryProvider);
    if (repository == null) {
      state = const SharedSettingsState(
        error: 'Supabase belum dikonfigurasi pada build ini (env.json).',
      );
      return;
    }
    _subscription = repository.watchSharedSettings().listen(
      (_) => refresh(),
      onError: (Object _) {}, // Refreshing on resume still covers it.
    );
    refresh();
  }

  final Ref _ref;
  StreamSubscription<void>? _subscription;
  Future<void>? _inFlight;

  /// One fetch now; a call while one is running joins it.
  Future<void> refresh() => _inFlight ??= _fetch().whenComplete(() {
    _inFlight = null;
  });

  Future<void> _fetch() async {
    final repository = _ref.read(tankRepositoryProvider);
    if (repository == null || !mounted) return;
    state = SharedSettingsState(
      isLoading: true,
      exists: state.exists,
      updatedAt: state.updatedAt,
    );
    try {
      final shared = await repository.fetchSharedSettings();
      if (shared != null) {
        await _ref.read(configProvider.notifier).applyShared(shared);
      }
      if (!mounted) return;
      state = SharedSettingsState(
        exists: shared != null,
        updatedAt: shared?.updatedAt,
      );
    } on TankSourceException catch (e) {
      if (!mounted) return;
      state = SharedSettingsState(
        exists: state.exists,
        updatedAt: state.updatedAt,
        error: e.message,
      );
    }
  }

  /// Throws [TankSourceException] unless [pin] is the admin PIN.
  Future<void> verifyPin(String pin) => _repository.verifySettingsPin(pin);

  /// Saves the shared part of [config] for every phone, then applies it here
  /// at once rather than waiting for the round trip through Realtime.
  Future<void> save(String pin, TankConfig config) async {
    final shared = SharedSettings.fromConfig(config);
    if (shared == null) {
      throw const TankSourceException('Pilih perangkat dan sensor dulu.');
    }
    await _repository.updateSharedSettings(pin, shared);
    await _ref.read(configProvider.notifier).applyShared(shared);
    unawaited(refresh());
  }

  TankRepository get _repository =>
      _ref.read(tankRepositoryProvider) ??
      (throw const TankSourceException(
        'Supabase belum dikonfigurasi pada build ini (env.json).',
      ));

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final sharedSettingsProvider =
    StateNotifierProvider<SharedSettingsNotifier, SharedSettingsState>(
      (ref) => SharedSettingsNotifier(ref),
    );
