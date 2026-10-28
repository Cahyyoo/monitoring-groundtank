import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/device.dart';
import '../models/sensor.dart';
import '../models/sensor_reading.dart';
import 'tank_source.dart' show TankSourceException;

/// Every query the app makes against the Supabase project, and nothing else.
///
/// Read-only by design: the app never writes to the sensor tables, so the
/// row-level-security policies in `supabase/setup.sql` grant SELECT only.
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
      throw TankSourceException('Gagal membaca database: ${e.message}');
    } on Exception catch (e) {
      // The HTTP client's own failures (DNS, TLS, a dropped socket) arrive as
      // types from packages this app does not depend on directly.
      debugPrint('Supabase request failed: $e');
      throw const TankSourceException('Tidak dapat terhubung ke Supabase.');
    }
  }
}
