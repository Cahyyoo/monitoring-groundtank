import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../models/chart_range.dart';
import '../../services/format.dart';
import '../../theme/app_theme.dart';

/// Asks for a span of days on a month calendar: one tap for the first day,
/// another for the last. Resolves to the choice, or null when cancelled.
///
/// [today] is the last day that can be picked; the real one unless a test
/// says otherwise.
Future<DateSpan?> showDateRangeSheet(
  BuildContext context, {
  DateSpan? initial,
  DateTime? today,
}) {
  return showCupertinoModalPopup<DateSpan>(
    context: context,
    builder: (_) =>
        _DateRangeSheet(initial: initial, today: today ?? DateTime.now()),
  );
}

DateTime _dayOf(DateTime at) => DateTime(at.year, at.month, at.day);

class _DateRangeSheet extends StatefulWidget {
  const _DateRangeSheet({required this.initial, required this.today});

  final DateSpan? initial;
  final DateTime today;

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  late final DateTime _today = _dayOf(widget.today);
  late DateTime _month;
  DateTime? _first;
  DateTime? _last;

  /// The first day is chosen and the next tap decides the last.
  bool get _awaitingLast => _first != null && _last == null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _first = _dayOf(initial.firstDay);
      _last = _dayOf(initial.lastDay);
    }
    final shown = _last ?? _today;
    _month = DateTime(shown.year, shown.month);
  }

  void _select(DateTime day) {
    setState(() {
      final first = _first;
      if (first == null || _last != null) {
        _first = day;
        _last = null;
      } else if (day.isBefore(first)) {
        _first = day;
        _last = first;
      } else {
        _last = day;
      }
    });
  }

  void _showMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final first = _first;
    final last = _last;
    final canGoForward = _month.isBefore(DateTime(_today.year, _today.month));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _TextAction(
                      label: 'Batal',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Rentang tanggal',
                        textAlign: TextAlign.center,
                        style: AppText.headline.copyWith(color: palette.label),
                      ),
                    ),
                    _TextAction(
                      label: 'Terapkan',
                      emphasized: true,
                      // One tap alone means that single day.
                      onPressed: first == null
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(DateSpan(first, last ?? first)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _EndCard(
                        title: 'Dari',
                        value: first == null
                            ? 'Ketuk tanggal awal'
                            : Format.date(first),
                        isPlaceholder: first == null,
                        isNext: !_awaitingLast,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _EndCard(
                        title: 'Sampai',
                        value: last != null
                            ? Format.date(last)
                            : _awaitingLast
                            ? 'Ketuk tanggal akhir'
                            : '–',
                        isPlaceholder: last == null,
                        isNext: _awaitingLast,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _MonthArrow(
                      icon: CupertinoIcons.chevron_left,
                      onPressed: () => _showMonth(-1),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy', 'id').format(_month),
                        textAlign: TextAlign.center,
                        style: AppText.subhead.copyWith(
                          color: palette.label,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _MonthArrow(
                      icon: CupertinoIcons.chevron_right,
                      onPressed: canGoForward ? () => _showMonth(1) : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _MonthGrid(
                  month: _month,
                  today: _today,
                  first: first,
                  last: last,
                  onSelect: _select,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Text(
        label,
        style: AppText.subhead.copyWith(
          color: onPressed == null ? palette.tertiaryLabel : palette.accent,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// One end of the range. The accent border marks the end the next tap sets.
class _EndCard extends StatelessWidget {
  const _EndCard({
    required this.title,
    required this.value,
    required this.isPlaceholder,
    required this.isNext,
  });

  final String title;
  final String value;
  final bool isPlaceholder;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isNext ? palette.accent : palette.separator,
          width: isNext ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.caption.copyWith(color: palette.secondaryLabel),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.footnote.copyWith(
              color: isPlaceholder ? palette.secondaryLabel : palette.label,
              fontWeight: isPlaceholder ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Icon(
        icon,
        size: 20,
        color: onPressed == null ? palette.tertiaryLabel : palette.accent,
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.first,
    required this.last,
    required this.onSelect,
  });

  static const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  /// Six weeks fit every month, and always drawing six keeps the sheet from
  /// changing height as the months go by.
  static const _weeks = 6;

  final DateTime month;
  final DateTime today;
  final DateTime? first;
  final DateTime? last;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final blanks = month.weekday - DateTime.monday;
    final days = DateTime(month.year, month.month + 1, 0).day;

    return Column(
      children: [
        Row(
          children: [
            for (final name in _weekdays)
              Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    color: palette.secondaryLabel,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var week = 0; week < _weeks; week++)
          Row(
            children: [
              for (var column = 0; column < DateTime.daysPerWeek; column++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final number =
                          week * DateTime.daysPerWeek + column - blanks + 1;
                      if (number < 1 || number > days) {
                        return const SizedBox(height: _DayCell.height);
                      }
                      final day = DateTime(month.year, month.month, number);
                      return _DayCell(
                        day: day,
                        isToday: day == today,
                        first: first,
                        last: last,
                        onTap: day.isAfter(today) ? null : () => onSelect(day),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.first,
    required this.last,
    required this.onTap,
  });

  static const double height = 44;
  static const double _circle = 36;

  final DateTime day;
  final bool isToday;
  final DateTime? first;
  final DateTime? last;

  /// Null for a day that has not happened yet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final start = first;
    final end = last;
    final isEnd = day == start || day == end;
    final inRange =
        start != null &&
        end != null &&
        !day.isBefore(start) &&
        !day.isAfter(end);

    final Color textColour;
    if (isEnd) {
      textColour = palette.onAccent;
    } else if (onTap == null) {
      textColour = palette.tertiaryLabel;
    } else {
      textColour = palette.label;
    }

    // The band runs through the middle of each cell and stops at the centre
    // of the two ends, joining their circles into one shape.
    Widget band(bool on) => Expanded(
      child: Container(height: _circle, color: on ? palette.accentTint : null),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                band(inRange && day != start),
                band(inRange && day != end),
              ],
            ),
            Container(
              width: _circle,
              height: _circle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isEnd ? palette.accent : null,
                shape: BoxShape.circle,
                border: isToday && !isEnd
                    ? Border.all(color: palette.accent)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: AppText.subhead.copyWith(
                  color: textColour,
                  fontWeight: isEnd || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
