import 'package:flutter/cupertino.dart';

import '../../models/chart_range.dart';
import '../../services/format.dart';
import '../../theme/app_theme.dart';

/// Asks for a span of days. Resolves to the choice, or null when cancelled.
///
/// A sheet of Cupertino wheels rather than Material's range picker, which
/// draws its controls with the icon font this app leaves out.
Future<DateSpan?> showDateRangeSheet(
  BuildContext context, {
  DateSpan? initial,
}) {
  return showCupertinoModalPopup<DateSpan>(
    context: context,
    builder: (_) => _DateRangeSheet(initial: initial),
  );
}

class _DateRangeSheet extends StatefulWidget {
  const _DateRangeSheet({this.initial});

  final DateSpan? initial;

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  late final DateTime _today;
  late DateTime _first;
  late DateTime _last;
  bool _editingFirst = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _first = widget.initial?.firstDay ?? _today;
    _last = widget.initial?.lastDay ?? _today;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget end(String title, DateTime day) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(
            title,
            style: AppText.caption.copyWith(color: palette.secondaryLabel),
          ),
          Text(
            Format.date(day),
            style: AppText.footnote.copyWith(
              color: palette.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Container(
      height: 400,
      color: palette.cardBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                CupertinoButton(
                  onPressed: () =>
                      Navigator.of(context).pop(DateSpan(_first, _last)),
                  child: const Text('Terapkan'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<bool>(
                  groupValue: _editingFirst,
                  children: {
                    true: end('Dari', _first),
                    false: end('Sampai', _last),
                  },
                  onValueChanged: (value) {
                    if (value != null) setState(() => _editingFirst = value);
                  },
                ),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                // A wheel reads its initial date only once, so each end gets
                // its own. The limits keep "Dari" from passing "Sampai".
                key: ValueKey(_editingFirst),
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _editingFirst ? _first : _last,
                minimumDate: _editingFirst ? null : _first,
                maximumDate: _editingFirst ? _last : _today,
                onDateTimeChanged: (value) {
                  final day = DateTime(value.year, value.month, value.day);
                  setState(() {
                    if (_editingFirst) {
                      _first = day;
                    } else {
                      _last = day;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
