import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../app_primitives.dart';

/// One figure on the dashboard: a tinted glyph, a label, the value, and an
/// optional line of context under it.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final ToneColors tone;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, tone: tone, size: 34),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.footnote.copyWith(color: palette.secondaryLabel),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: AppText.title2.copyWith(color: palette.label),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: palette.secondaryLabel),
            ),
          ],
        ],
      ),
    );
  }
}
