import 'package:intl/intl.dart';

import '../models/tank_config.dart';
import '../models/tank_level.dart';

/// Number and time wording, Indonesian throughout.
abstract final class Format {
  static final _whole = NumberFormat.decimalPattern('id');
  static final _oneDecimal = NumberFormat('#,##0.0', 'id');
  static final _upToOneDecimal = NumberFormat('#,##0.#', 'id');

  /// `7.200 L`
  static String liters(double value) => '${_whole.format(value.round())} L';

  /// `145 cm`
  static String cm(double value) => '${_whole.format(value.round())} cm';

  /// `109,8 cm` — always one decimal, for a measured height.
  static String cmPrecise(double value) => '${_oneDecimal.format(value)} cm';

  /// `180 cm` or `180,5 cm` — a decimal only when there is one, for a
  /// dimension typed into Settings.
  static String cmCompact(double value) =>
      '${_upToOneDecimal.format(value)} cm';

  /// `72%`
  static String percent(double value) => '${value.round()}%';

  /// `+1,2` with its sign, for a rate.
  static String signed(double value) =>
      '${value >= 0 ? '+' : '–'}${_oneDecimal.format(value.abs())}';

  /// `14.03.22`
  static String clock(DateTime at) => DateFormat('HH.mm.ss', 'id').format(at);

  /// `22 Okt 2026, 14.03`
  static String dateTime(DateTime at) =>
      DateFormat('d MMM yyyy, HH.mm', 'id').format(at);

  /// `baru saja`, `12 dtk lalu`, `5 mnt lalu`, `3 jam lalu`, then a date.
  static String relative(DateTime at, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(at);
    if (diff.inSeconds < 5) return 'baru saja';
    if (diff.inSeconds < 60) return '${diff.inSeconds} dtk lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return dateTime(at);
  }

  /// `~12 mnt`, `~2 jam 5 mnt`
  static String duration(double minutes) {
    final total = minutes.round();
    if (total < 1) return 'kurang dari 1 mnt';
    if (total < 60) return '~$total mnt';
    final h = total ~/ 60;
    final m = total % 60;
    return m == 0 ? '~$h jam' : '~$h jam $m mnt';
  }

  static String levelLabel(TankLevel? level) => switch (level) {
    TankLevel.full => 'Penuh',
    TankLevel.empty => 'Kosong',
    TankLevel.normal => 'Normal',
    null => 'Menunggu data',
  };

  static String valueKind(ValueKind kind) => switch (kind) {
    ValueKind.percent => 'Persen terisi',
    ValueKind.levelCm => 'Tinggi air',
    ValueKind.distanceCm => 'Jarak sensor ke air',
  };

  static String alertTitle(TankAlertKind kind) => switch (kind) {
    TankAlertKind.full => 'Ground tank penuh',
    TankAlertKind.empty => 'Ground tank kosong',
  };

  /// [byFloat]: the float switch, not the level, made it full.
  static String alertBody(
    TankAlertKind kind,
    double percent, {
    bool byFloat = false,
  }) => switch (kind) {
    TankAlertKind.full when byFloat =>
      'Pelampung mendeteksi air penuh (sensor ketinggian ${Format.percent(percent)}). '
          'Matikan pompa pengisian agar tidak meluap.',
    TankAlertKind.full =>
      'Air mencapai ${Format.percent(percent)}. Matikan pompa pengisian agar tidak meluap.',
    TankAlertKind.empty =>
      'Air tersisa ${Format.percent(percent)}. Segera isi ulang ground tank.',
  };

  static String floatState(bool? full) => switch (full) {
    true => 'Penuh',
    false => 'Belum penuh',
    null => 'Belum ada data',
  };
}
