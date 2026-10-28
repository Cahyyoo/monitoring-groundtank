import 'package:flutter/foundation.dart';

/// A row of `devices`: one microcontroller in the field.
@immutable
class Device {
  const Device({
    required this.id,
    required this.name,
    this.project,
    this.ipAddress,
    this.isActive = false,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? project;
  final String? ipAddress;

  /// The `status` column.
  final bool isActive;

  final DateTime? updatedAt;

  /// Columns the app reads; kept beside [fromRow] so the two cannot drift.
  static const columns = 'id, name, project, ip_address, status, updated_at';

  factory Device.fromRow(Map<String, dynamic> row) {
    return Device(
      id: row['id'] as String,
      name: _text(row['name']) ?? 'Perangkat tanpa nama',
      project: _text(row['project']),
      ipAddress: _text(row['ip_address']),
      isActive: row['status'] == true,
      updatedAt: row['updated_at'] is String
          ? DateTime.tryParse(row['updated_at'] as String)?.toLocal()
          : null,
    );
  }
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
