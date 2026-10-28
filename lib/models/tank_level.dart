/// The three states the app reasons about.
///
/// Deliberately coarse: a notification is sent on entering [full] or [empty],
/// and nothing finer than that is worth a user's attention.
enum TankLevel { empty, normal, full }

/// What a notification is about.
enum TankAlertKind { full, empty }

/// One notification that was raised, kept for the Notifikasi tab.
class AlertEntry {
  const AlertEntry({
    required this.kind,
    required this.percent,
    required this.at,
  });

  final TankAlertKind kind;
  final double percent;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'percent': percent,
    'at': at.millisecondsSinceEpoch,
  };

  /// Null for anything unreadable, so one bad row cannot empty the log.
  static AlertEntry? tryParse(Map<String, Object?> json) {
    final kind = TankAlertKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final percent = json['percent'];
    final at = json['at'];
    if (kind == null || percent is! num || at is! int) return null;
    return AlertEntry(
      kind: kind,
      percent: percent.toDouble(),
      at: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }
}
