import 'package:flutter/cupertino.dart';

import '../../theme/app_theme.dart';

/// The hairline between two rows of an inset card, inset from the leading
/// edge so a list of rows reads as one group.
///
/// The explicit width matters: a childless [ColoredBox] sizes to the smallest
/// constraint, and under a loosely-constrained Column it would draw nothing.
class InsetHairline extends StatelessWidget {
  const InsetHairline({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      child: SizedBox(
        height: 0.5,
        width: double.infinity,
        child: ColoredBox(color: context.palette.separator),
      ),
    );
  }
}

/// The grouped list: a soft white card of rows on the page's own ground.
class InsetSection extends StatelessWidget {
  const InsetSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.footerIsError = false,
    this.actionLabel,
    this.onAction,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  /// Colours [footer] red, for a validation message.
  final bool footerIsError;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            InsetSectionHeading(
              text: header!,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: ColoredBox(
              color: palette.cardBackground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1) const InsetHairline(),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                footer!,
                style: AppText.footnote.copyWith(
                  color: footerIsError
                      ? palette.danger.foreground
                      : palette.secondaryLabel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One row inside an [InsetSection]. A tapped row dims to the fill and back —
/// no ripple anywhere.
class InsetRow extends StatefulWidget {
  const InsetRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleStyle,
    this.showChevron = false,
    this.isDestructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final bool showChevron;
  final bool isDestructive;

  @override
  State<InsetRow> createState() => _InsetRowState();
}

class _InsetRowState extends State<InsetRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      widget.titleStyle ??
                      AppText.body.copyWith(
                        color: widget.isDestructive
                            ? palette.danger.foreground
                            : palette.label,
                      ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.footnote.copyWith(
                      color: palette.secondaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            widget.trailing!,
          ],
          if (widget.showChevron) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: palette.tertiaryLabel,
            ),
          ],
        ],
      ),
    );

    if (widget.onTap == null) {
      return ColoredBox(color: palette.cardBackground, child: content);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: ColoredBox(
        color: _isPressed ? palette.fill : palette.cardBackground,
        child: content,
      ),
    );
  }
}

/// A row whose whole body is supplied by the caller.
class InsetCustomRow extends StatelessWidget {
  const InsetCustomRow({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.palette.cardBackground,
      child: Padding(
        padding:
            padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
        child: child,
      ),
    );
  }
}

/// A bold section heading with an optional accent link on its right.
class InsetSectionHeading extends StatelessWidget {
  const InsetSectionHeading({
    super.key,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        0,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.headline.copyWith(color: palette.label),
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Text(
                    actionLabel!,
                    style: AppText.footnote.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
