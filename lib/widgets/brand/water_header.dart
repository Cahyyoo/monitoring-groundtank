import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';

/// Atara's GreenHeader, recoloured for water: navy in the top-left corner into
/// cyan at the bottom-right, rounded bottom corners, running up under the
/// status bar — with two faint swells along the bottom edge.
class WaterHeader extends StatelessWidget {
  const WaterHeader({super.key, this.child, this.radius = AppRadius.header});

  final Widget? child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = BorderRadius.vertical(bottom: Radius.circular(radius));
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: palette.heroGradient,
        borderRadius: shape,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: palette.heroSheenGradient,
          borderRadius: shape,
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: CustomPaint(
            painter: _SwellPainter(palette.onHero),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}

class _SwellPainter extends CustomPainter {
  _SwellPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    void swell(double height, double phase, double alpha) {
      final base = size.height - height;
      final path = Path()..moveTo(0, base);
      for (var x = 0.0; x <= size.width; x += 4) {
        path.lineTo(
          x,
          base + 10 * math.sin(2 * math.pi * (x / size.width * 1.2 + phase)),
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = colour.withValues(alpha: alpha));
    }

    swell(44, 0.1, 0.05);
    swell(26, 0.55, 0.06);
  }

  @override
  bool shouldRepaint(_SwellPainter oldDelegate) => oldDelegate.colour != colour;
}
