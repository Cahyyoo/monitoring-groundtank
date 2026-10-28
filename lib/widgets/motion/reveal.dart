import 'package:flutter/widgets.dart';

import '../../theme/app_motion.dart';

/// Fades [child] in while it travels [offset] back to its place, driven by
/// [animation] running 0 → 1. With animations disabled the travel is dropped
/// and the fade kept.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.animation,
    required this.child,
    this.offset = const Offset(0, AppMotion.rise),
  });

  final Animation<double> animation;
  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    if (!AppMotion.reduced(context) && offset != Offset.zero) {
      result = AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: offset * (1 - animation.value),
          child: child,
        ),
      );
    }
    return FadeTransition(opacity: animation, child: result);
  }
}

/// A [Reveal] that plays itself once, [delay] after it first appears.
class EnterReveal extends StatefulWidget {
  const EnterReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.base,
    this.offset = const Offset(0, AppMotion.rise),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<EnterReveal> createState() => _EnterRevealState();
}

class _EnterRevealState extends State<EnterReveal>
    with SingleTickerProviderStateMixin {
  // The delay is the front of the controller's own run rather than a timer:
  // a pending Future.delayed outlives a widget test and fails it.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
    animationBehavior: AnimationBehavior.preserve,
  )..forward();

  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.inMicroseconds /
          (widget.delay + widget.duration).inMicroseconds,
      1,
      curve: AppMotion.enter,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Reveal(
      animation: _curved,
      offset: widget.offset,
      child: widget.child,
    );
  }
}
