import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

import '../../theme/app_theme.dart';

enum AppButtonStyle {
  /// The one action a screen exists for: a navy-into-blue gradient pill.
  filled,

  /// A secondary action: an accent label on the field-coloured pill.
  tinted,

  /// Accent label, no container.
  plain,
}

/// A full pill that dims and gives slightly when pressed. No elevation, no
/// ripple, no border.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = AppButtonStyle.filled,
    this.icon,
    this.isBusy = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;

  /// Replaces the label with a spinner without resizing the button.
  final bool isBusy;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = widget.onPressed != null && !widget.isBusy;
    final isSolid = widget.style == AppButtonStyle.filled;

    final (Color background, Color foreground) = switch (widget.style) {
      AppButtonStyle.filled => (palette.accent, palette.onAccent),
      AppButtonStyle.tinted => (palette.field, palette.accent),
      AppButtonStyle.plain => (Colors.transparent, palette.accent),
    };

    final Widget child = widget.isBusy
        ? CupertinoActivityIndicator(color: foreground, radius: 11)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );

    return AnimatedOpacity(
      opacity: enabled ? (_isPressed ? 0.7 : 1) : 0.4,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onPressed : null,
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: widget.expand ? double.infinity : null,
            // A minimum, not a fixed height, so a large system font wraps the
            // label instead of clipping it.
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              color: isSolid ? null : background,
              gradient: isSolid ? palette.primaryGradient : null,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(widget.isBusy ? null : widget.label),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
