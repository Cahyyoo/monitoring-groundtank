import 'package:flutter/widgets.dart';

import '../../theme/app_motion.dart';

/// Answers a touch the way Atara's cards do: they give a little under the
/// finger and spring back. A quick tap always plays the whole press before
/// [onTap] runs, so it is never invisible.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.96,
    this.semanticLabel,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 160),
    animationBehavior: AnimationBehavior.preserve,
  );

  late final Animation<double> _curved = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOut,
  );

  bool _tapping = false;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    final onTap = widget.onTap;
    if (onTap == null || _tapping) return;
    _tapping = true;
    try {
      await _press.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    onTap();
    _tapping = false;
    if (mounted) _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget body = FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.85).animate(_curved),
      child: widget.child,
    );
    if (!AppMotion.reduced(context)) {
      body = ScaleTransition(
        scale: Tween<double>(begin: 1, end: widget.scale).animate(_curved),
        child: body,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _tap : null,
        onTapDown: enabled && !_tapping ? (_) => _press.forward() : null,
        onTapCancel: enabled && !_tapping ? () => _press.reverse() : null,
        child: body,
      ),
    );
  }
}
