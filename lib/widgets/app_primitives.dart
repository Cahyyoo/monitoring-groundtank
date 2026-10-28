import 'package:flutter/cupertino.dart';

import '../models/tank_level.dart';
import '../theme/app_theme.dart';

/// A small tinted capsule carrying one word: a status, a tally.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final ToneColors tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone.onBackground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppText.caption.copyWith(
              color: tone.onBackground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded square holding one glyph, tinted by [tone].
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.tone,
    this.size = 36,
  });

  final IconData icon;
  final ToneColors tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.52, color: tone.foreground),
    );
  }
}

/// The tone, icon and word for each tank state, so every screen colours a
/// state the same way.
extension TankLevelStyle on TankLevel? {
  ToneColors tone(AppColors palette) => switch (this) {
    TankLevel.full => palette.info,
    TankLevel.empty => palette.danger,
    TankLevel.normal => palette.success,
    null => ToneColors(
      foreground: palette.secondaryLabel,
      background: palette.fill,
      onBackground: palette.secondaryLabel,
    ),
  };

  IconData get icon => switch (this) {
    TankLevel.full => CupertinoIcons.drop_fill,
    TankLevel.empty => CupertinoIcons.exclamationmark_triangle_fill,
    TankLevel.normal => CupertinoIcons.checkmark_seal_fill,
    null => CupertinoIcons.hourglass,
  };
}

extension AlertKindStyle on TankAlertKind {
  TankLevel get level => switch (this) {
    TankAlertKind.full => TankLevel.full,
    TankAlertKind.empty => TankLevel.empty,
  };
}
