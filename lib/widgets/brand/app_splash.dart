import 'package:flutter/widgets.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../dashboard/tank_gauge.dart';
import 'water_header.dart';

/// Covers [child] on launch with a tank filling up and the app's name, then
/// fades away to reveal it.
///
/// [child] runs underneath the whole time, so the dashboard has usually got its
/// data by the time it shows.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  /// Short of the brim, so the moving surface stays in sight.
  static const double _waterLevel = 0.92;

  // The stages, as parts of the whole two seconds.
  static const Curve _fill = Interval(0, 0.7, curve: AppMotion.move);
  static const Curve _title = Interval(0.25, 0.55, curve: AppMotion.enter);
  static const Curve _fadeOut = Interval(0.85, 1, curve: AppMotion.exit);

  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
        // By default less motion would cut this to a 0.1 s flash.
        animationBehavior: AnimationBehavior.preserve,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _done = true);
        }
      });

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_done)
          AbsorbPointer(
            child: AnimatedBuilder(animation: _controller, builder: _splash),
          ),
      ],
    );
  }

  Widget _splash(BuildContext context, Widget? _) {
    final palette = context.palette;
    final t = _controller.value;
    // Fades keep their timing when the platform asks for less motion; the water
    // and the title simply stay where they end up.
    final reduced = AppMotion.reduced(context);
    final titleIn = _title.transform(t);

    return Opacity(
      opacity: 1 - _fadeOut.transform(t),
      child: WaterHeader(
        radius: 0,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(132, 186),
                painter: TankPainter(
                  level: reduced
                      ? _waterLevel
                      : _waterLevel * _fill.transform(t),
                  phase: reduced ? 0 : t,
                  glass: palette.onHero,
                  water: palette.waterGradient,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Opacity(
                opacity: titleIn,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    reduced ? 0 : AppMotion.rise * (1 - titleIn),
                  ),
                  child: Text(
                    'GroundTank',
                    style: AppText.largeTitle.copyWith(color: palette.onHero),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
