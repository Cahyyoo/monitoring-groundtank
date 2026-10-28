import 'package:flutter/cupertino.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../motion/reveal.dart';

/// A screen with an iOS large title that shrinks into the bar as it scrolls.
///
/// Use [AppPage.list] for a plain column of sections, which arrive one beat
/// after another as Atara's do.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.onRefresh,
  });

  AppPage.list({
    super.key,
    required this.title,
    required List<Widget> children,
    this.trailing,
    this.onRefresh,
  }) : slivers = [
         SliverPadding(
           padding: const EdgeInsets.fromLTRB(
             AppSpacing.lg,
             AppSpacing.sm,
             AppSpacing.lg,
             AppSpacing.xxl,
           ),
           sliver: SliverList(
             delegate: SliverChildListDelegate([
               for (var i = 0; i < children.length; i++)
                 i < 6
                     ? EnterReveal(
                         delay: AppMotion.stagger * (i + 1),
                         child: children[i],
                       )
                     : children[i],
             ]),
           ),
         ),
       ];

  final String title;
  final List<Widget> slivers;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return CupertinoPageScaffold(
      backgroundColor: palette.groupedBackground,
      child: CustomScrollView(
        // Bouncing + AlwaysScrollable, or pull-to-refresh is dead on Android
        // (Clamping physics never overscrolls) and on any page shorter than
        // the screen.
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            // Opaque: a translucent colour inserts a BackdropFilter, the most
            // expensive primitive there is.
            backgroundColor: palette.groupedBackground,
            border: null,
            trailing: trailing,
            automaticallyImplyLeading: false,
          ),
          if (onRefresh != null)
            CupertinoSliverRefreshControl(onRefresh: onRefresh),
          ...slivers,
        ],
      ),
    );
  }
}

/// The text or icon button in a navigation bar.
class NavBarAction extends StatelessWidget {
  const NavBarAction({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.isDestructive = false,
  });

  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colour = isDestructive ? palette.danger.foreground : palette.accent;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: icon != null
          ? Icon(icon, size: 22, color: colour)
          : Text(label ?? '', style: AppText.body.copyWith(color: colour)),
    );
  }
}
