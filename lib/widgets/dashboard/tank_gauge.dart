import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';

/// A glass tank on the hero header with the water inside it, its surface
/// rolling gently and gliding to each new reading.
///
/// Dashed lines mark the full and empty thresholds, so it is visible at a
/// glance how close the water is to raising a notification.
class TankGauge extends StatefulWidget {
  const TankGauge({
    super.key,
    required this.percent,
    required this.fullThreshold,
    required this.emptyThreshold,
    this.width = 116,
    this.height = 164,
  });

  /// Null while there is no reading yet: an empty tank with no surface.
  final double? percent;
  final int fullThreshold;
  final int emptyThreshold;
  final double width;
  final double height;

  @override
  State<TankGauge> createState() => _TankGaugeState();
}

class _TankGaugeState extends State<TankGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The surface lies flat when the platform asks for less motion.
    if (AppMotion.reduced(context)) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final target = (widget.percent ?? 0) / 100;

    return Semantics(
      label: widget.percent == null
          ? 'Tangki, menunggu data'
          : 'Tangki terisi ${widget.percent!.round()} persen',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: AppMotion.slow,
        curve: AppMotion.move,
        builder: (context, level, _) => AnimatedBuilder(
          animation: _wave,
          builder: (context, _) => CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _TankPainter(
              level: widget.percent == null ? 0 : level,
              phase: _wave.value,
              full: widget.fullThreshold / 100,
              empty: widget.emptyThreshold / 100,
              glass: palette.onHero,
              water: palette.waterGradient,
            ),
          ),
        ),
      ),
    );
  }
}

class _TankPainter extends CustomPainter {
  _TankPainter({
    required this.level,
    required this.phase,
    required this.full,
    required this.empty,
    required this.glass,
    required this.water,
  });

  final double level;
  final double phase;
  final double full;
  final double empty;
  final Color glass;
  final LinearGradient water;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );

    canvas.drawRRect(body, Paint()..color = glass.withValues(alpha: 0.10));

    canvas.save();
    canvas.clipRRect(body);
    if (level > 0.002) {
      // Calmer near the brim and the floor, where a big swell would poke out
      // of the tank or read as water that is not there.
      final amplitude =
          5 * (math.min(level, 1 - level) * 8).clamp(0.25, 1.0).toDouble();
      final surface = size.height * (1 - level);
      final shader = water.createShader(Offset.zero & size);

      canvas.drawPath(
        _wavePath(size, surface - 2, amplitude, phase + 0.5),
        Paint()..color = water.colors.first.withValues(alpha: 0.45),
      );
      canvas.drawPath(
        _wavePath(size, surface, amplitude, phase),
        Paint()..shader = shader,
      );
    }

    // Scale ticks at the quarters, on the leading edge.
    final tick = Paint()
      ..color = glass.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    for (final q in const [0.25, 0.5, 0.75]) {
      final y = size.height * (1 - q);
      canvas.drawLine(Offset(0, y), Offset(q == 0.5 ? 14 : 9, y), tick);
    }

    _dashed(canvas, size, full);
    _dashed(canvas, size, empty);
    canvas.restore();

    canvas.drawRRect(
      body.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = glass.withValues(alpha: 0.6),
    );

    // A highlight down the glass, as on a real tank sight-glass.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.72, 14, 6, size.height - 28),
        const Radius.circular(3),
      ),
      Paint()..color = glass.withValues(alpha: 0.16),
    );
  }

  Path _wavePath(Size size, double surface, double amplitude, double phase) {
    final path = Path()..moveTo(0, surface);
    for (var x = 0.0; x <= size.width; x += 2) {
      path.lineTo(
        x,
        surface +
            amplitude * math.sin(2 * math.pi * (x / size.width * 1.1 + phase)),
      );
    }
    return path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  void _dashed(Canvas canvas, Size size, double at) {
    final y = size.height * (1 - at);
    final paint = Paint()
      ..color = glass.withValues(alpha: 0.85)
      ..strokeWidth = 1.5;
    for (var x = 6.0; x < size.width - 6; x += 9) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 5, size.width - 6), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TankPainter old) =>
      old.level != level ||
      old.phase != phase ||
      old.full != full ||
      old.empty != empty ||
      old.glass != glass ||
      old.water != water;
}
