import 'package:flutter/widgets.dart';

import '../../models/tank_reading.dart';
import '../../services/format.dart';
import '../../theme/app_theme.dart';

/// The last few minutes of readings as a line, with the two thresholds drawn
/// across it.
class LevelChart extends StatelessWidget {
  const LevelChart({
    super.key,
    required this.history,
    required this.fullThreshold,
    required this.emptyThreshold,
    this.height = 160,
  });

  final List<TankReading> history;
  final int fullThreshold;
  final int emptyThreshold;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppText.caption.copyWith(color: palette.secondaryLabel);

    if (history.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Mengumpulkan data…',
            style: AppText.footnote.copyWith(color: palette.secondaryLabel),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _ChartPainter(
              history: history,
              full: fullThreshold.toDouble(),
              empty: emptyThreshold.toDouble(),
              line: palette.accent,
              grid: palette.separator,
              fullColour: palette.info.foreground,
              emptyColour: palette.danger.foreground,
              labelStyle: caption,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(left: _ChartPainter.axisWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(Format.clock(history.first.measuredAt), style: caption),
              Text(Format.clock(history.last.measuredAt), style: caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.history,
    required this.full,
    required this.empty,
    required this.line,
    required this.grid,
    required this.fullColour,
    required this.emptyColour,
    required this.labelStyle,
  });

  static const double axisWidth = 34;

  final List<TankReading> history;
  final double full;
  final double empty;
  final Color line;
  final Color grid;
  final Color fullColour;
  final Color emptyColour;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(axisWidth, 6, size.width, size.height - 6);
    double yOf(double percent) => plot.bottom - plot.height * percent / 100;

    final start = history.first.measuredAt.millisecondsSinceEpoch;
    final span = (history.last.measuredAt.millisecondsSinceEpoch - start).clamp(
      1,
      1 << 62,
    );
    double xOf(TankReading r) =>
        plot.left +
        plot.width * (r.measuredAt.millisecondsSinceEpoch - start) / span;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final p in const [0.0, 50.0, 100.0]) {
      final y = yOf(p);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final label = TextPainter(
        text: TextSpan(text: '${p.round()}%', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - label.height / 2));
    }

    _dashed(canvas, plot, yOf(full), fullColour);
    _dashed(canvas, plot, yOf(empty), emptyColour);

    final path = Path();
    for (var i = 0; i < history.length; i++) {
      final point = Offset(xOf(history[i]), yOf(history[i].percent));
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }

    final area = Path.from(path)
      ..lineTo(xOf(history.last), plot.bottom)
      ..lineTo(xOf(history.first), plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.22), line.withValues(alpha: 0)],
        ).createShader(plot),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final last = Offset(xOf(history.last), yOf(history.last.percent));
    canvas.drawCircle(last, 5, Paint()..color = line.withValues(alpha: 0.25));
    canvas.drawCircle(last, 3, Paint()..color = line);
  }

  void _dashed(Canvas canvas, Rect plot, double y, Color colour) {
    final paint = Paint()
      ..color = colour.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    for (var x = plot.left; x < plot.right; x += 8) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 4).clamp(0, plot.right), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      !identical(old.history, history) ||
      old.full != full ||
      old.empty != empty ||
      old.line != line ||
      old.grid != grid;
}
