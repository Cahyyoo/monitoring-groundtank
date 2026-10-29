import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/device.dart';
import '../models/sensor.dart';
import '../services/tank_repository.dart';

/// Null when this build has no Supabase keys, or initialising failed; every
/// read then explains that instead. Overridden in tests.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!Env.isSupabaseConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

final tankRepositoryProvider = Provider<TankRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : TankRepository(client);
});

/// For the device picker; refetched each time it opens.
final devicesProvider = FutureProvider.autoDispose<List<Device>>((ref) async {
  final repository = ref.watch(tankRepositoryProvider);
  if (repository == null) return const [];
  return repository.fetchDevices();
});

/// For the sensor picker of one device.
final deviceSensorsProvider = FutureProvider.autoDispose
    .family<List<Sensor>, String>((ref, deviceId) async {
      final repository = ref.watch(tankRepositoryProvider);
      if (repository == null) return const [];
      return repository.fetchDeviceSensors(deviceId);
    });
