import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A brief message that fades in over whatever is on screen.
///
/// Goes through the root [Overlay] rather than a ScaffoldMessenger, because
/// the Cupertino page scaffolds here have no Material Scaffold to find.
class AppToast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(BuildContext context, String message, {IconData? icon}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // A second message replaces the first rather than stacking behind it.
    _dismiss();
    // Above the tab bar, or above the keyboard while one is open — measured
    // from the root, since the shell trims the insets its pages see.
    final media = MediaQuery.of(overlay.context);
    final keyboard = media.viewInsets.bottom;
    final bottom = keyboard > 0
        ? keyboard + AppSpacing.xl
        : media.padding.bottom + 90;

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: bottom,
        child: IgnorePointer(
          child: _ToastBody(message: message, icon: icon),
        ),
      ),
    );

    _current = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 2600), _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastBody extends StatefulWidget {
  const _ToastBody({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  State<_ToastBody> createState() => _ToastBodyState();
}

class _ToastBodyState extends State<_ToastBody> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Always the dark capsule, in both appearances: a near-black navy, so it
    // belongs to the palette.
    const background = Color(0xF20B1424);

    return AnimatedSlide(
      offset: Offset(0, _opacity == 0 ? 0.4 : 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 180),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: AppText.subhead.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
