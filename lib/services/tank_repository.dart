import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase/supabase.dart';

import '../models/device.dart';
import '../models/sensor.dart';
import '../models/shared_settings.dart';
import '../models/sensor_reading.dart';
import 'tank_source.dart' show TankSourceException;

/// Every query the app makes against the Supabase project, and nothing else.
///
/// Read-only by design: the app never writes to a table, so the
/// row-level-security policies in `supabase/setup.sql` grant SELECT only.
/// The shared settings change through `update_tank_settings`, a function
/// that checks the admin PIN itself.
class TankRepository {
  TankRepository(this._client);

  final SupabaseClient _client;

  static const _readings = 'sensor_readings';

  Future<List<Device>> fetchDevices() => _guard(() async {
    final rows = await _client
        .from('devices')
        .select(Device.columns)
        .order('name');
    return rows.map(Device.fromRow).toList();
  });

  /// The sensors wired to [deviceId], through `device_sensors`.
  Future<List<Sensor>> fetchDeviceSensors(String deviceId) => _guard(() async {
    final rows = await _client
        .from('device_sensors')
        .select(Sensor.deviceSensorColumns)
        .eq('device_id', deviceId)
        .order('created_at');
    return [for (final row in rows) ?Sensor.fromDeviceSensorRow(row)];
  });

  /// The newest usable reading, or null when the sensor has sent none.
  ///
  /// Asks for a few rows rather than one, so a single unparsable value at the
  /// top of the table does not hide the good reading just below it.
  Future<SensorReading?> fetchLatest(String deviceId, String sensorId) =>
      _guard(() async {
        final rows = await _query(
          deviceId,
          sensorId,
        ).order('timestamp', ascending: false).limit(5);
        return rows.map(SensorReading.fromRow).nonNulls.firstOrNull;
      });

  /// Readings since [since], oldest first, at most [limit] of the newest.
  Future<List<SensorReading>> fetchSince(
    String deviceId,
    String sensorId,
    DateTime since, {
    int limit = 120,
  }) => _guard(() async {
    final rows = await _query(deviceId, sensorId)
        .gte('timestamp', since.toUtc().toIso8601String())
        .order('timestamp', ascending: false)
        .limit(limit);
    return rows.map(SensorReading.fromRow).nonNulls.toList().reversed.toList();
  });

  /// New rows for [sensorId] as they are inserted.
  ///
  /// Realtime accepts one filter per subscription, so the server filters on
  /// the device and the sensor is checked here. Needs `sensor_readings` in
  /// the `supabase_realtime` publication; without it the stream stays silent
  /// and polling carries on alone. The channel is removed when the listener
  /// cancels.
  Stream<SensorReading> watchInserts(String deviceId, String sensorId) {
    late final RealtimeChannel channel;
    final controller = StreamController<SensorReading>();

    controller
      ..onListen = () {
        channel = _client
            .channel('readings:$deviceId:$sensorId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: _readings,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'device_id',
                value: deviceId,
              ),
              callback: (payload) {
                final row = payload.newRecord;
                if (row['sensor_id'] != sensorId) return;
                final reading = SensorReading.fromRow(row);
                if (reading != null && !controller.isClosed) {
                  controller.add(reading);
                }
              },
            )
            .subscribe();
      }
      ..onCancel = () async {
        await _client.removeChannel(channel);
        await controller.close();
      };

    return controller.stream;
  }

  /// The settings every phone shares, or null when none have been saved.
  Future<SharedSettings?> fetchSharedSettings() => _guard(() async {
    final row = await _client
        .from('tank_settings')
        .select(SharedSettings.columns)
        .eq('id', 1)
        .maybeSingle();
    return row == null ? null : SharedSettings.fromRow(row);
  });

  /// Fires whenever the shared row changes, so the phone can refetch it with
  /// the names embedded. Silent without `tank_settings` in the Realtime
  /// publication; the phone then picks changes up when it is reopened.
  Stream<void> watchSharedSettings() {
    late final RealtimeChannel channel;
    final controller = StreamController<void>();

    controller
      ..onListen = () {
        channel = _client
            .channel('tank_settings')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'tank_settings',
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe();
      }
      ..onCancel = () async {
        await _client.removeChannel(channel);
        await controller.close();
      };

    return controller.stream;
  }

  /// Completes when [pin] is the admin PIN; otherwise throws with the reason.
  Future<void> verifySettingsPin(String pin) => _guard(() async {
    final status = await _client.rpc<Object?>(
      'verify_settings_pin',
      params: {'p_pin': pin},
    );
    _throwUnlessOk(status);
  });

  /// Saves [settings] for every phone, if [pin] is the admin PIN.
  Future<void> updateSharedSettings(String pin, SharedSettings settings) =>
      _guard(() async {
        final status = await _client.rpc<Object?>(
          'update_tank_settings',
          params: settings.rpcParams(pin),
        );
        _throwUnlessOk(status);
      });

  /// The settings functions answer with a status rather than an error, so a
  /// wrong PIN is still counted towards the lockout.
  static void _throwUnlessOk(Object? status) {
    if (status == 'ok') return;
    final message = switch (status) {
      'wrong_pin' => 'PIN salah.',
      'locked' => 'Terlalu banyak PIN salah. Coba lagi dalam 5 menit.',
      'no_pin' =>
        'PIN admin belum dibuat. Buat dulu di Supabase (lihat README).',
      final String s when s.startsWith('invalid:') =>
        'Server menolak pengaturan: ${_fieldLabel(s.substring(8))} tidak valid.',
      _ => 'Jawaban server tidak dikenal: $status',
    };
    throw TankSourceException(message);
  }

  static String _fieldLabel(String field) => switch (field) {
    'device_id' => 'perangkat',
    'level_sensor_id' => 'sensor ketinggian',
    'float_sensor_id' => 'sensor pelampung',
    'value_kind' => 'arti nilai',
    'tank_height_cm' => 'tinggi air maksimum',
    'sensor_to_bottom_cm' => 'jarak sensor ke dasar',
    'capacity_liters' => 'kapasitas',
    'thresholds' => 'batas penuh/kosong',
    _ => field,
  };

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _query(
    String deviceId,
    String sensorId,
  ) => _client
      .from(_readings)
      .select(SensorReading.columns)
      .eq('device_id', deviceId)
      .eq('sensor_id', sensorId);

  /// Turns client exceptions into a sentence for the dashboard.
  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run().timeout(const Duration(seconds: 10));
    } on TankSourceException {
      rethrow; // Already worded for the screen.
    } on TimeoutException {
      throw const TankSourceException(
        'Database tidak merespons. Periksa koneksi internet.',
      );
    } on SocketException {
      throw const TankSourceException('Tidak ada koneksi internet.');
    } on PostgrestException catch (e) {
      // 42501: insufficient privilege — RLS is on with no SELECT policy.
      if (e.code == '42501' || e.code == 'PGRST301') {
        throw const TankSourceException(
          'Akses ditolak database. Jalankan kebijakan RLS di supabase/setup.sql.',
        );
      }
      // A table or function setup.sql creates is not there yet.
      if (e.code == 'PGRST202' || e.code == 'PGRST205' || e.code == '42P01') {
        throw const TankSourceException(
          'Database belum disiapkan. Jalankan supabase/setup.sql di Supabase.',
        );
      }
      throw TankSourceException('Gagal membaca database: ${e.message}');
    } on Exception catch (e) {
      // The HTTP client's own failures (DNS, TLS, a dropped socket) arrive as
      // types from packages this app does not depend on directly.
      debugPrint('Supabase request failed: $e');
      throw const TankSourceException('Tidak dapat terhubung ke Supabase.');
    }
  }
}
