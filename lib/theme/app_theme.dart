import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

export 'app_colors.dart' show AppColors, ToneColors;
export 'app_typography.dart' show AppText;

/// One vertical and horizontal rhythm for the whole app.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// The gutter every full screen uses.
  static const EdgeInsets page = EdgeInsets.all(lg);
}

abstract final class AppRadius {
  /// Badges and small chips.
  static const double sm = 10;

  /// Icon tiles and inner blocks inside a card.
  static const double md = 14;

  /// The cards that carry almost every row.
  static const double lg = 18;

  /// Sheets, dialogs, the hero card.
  static const double xl = 24;

  /// The bottom corners of the hero header.
  static const double header = 28;

  /// Buttons, capsules: always fully round.
  static const double pill = 999;
}

/// Shorthand for the lookups nearly every widget here needs.
extension AppThemeContext on BuildContext {
  /// Falls back to the light palette rather than asserting, so a widget built
  /// under a plain [MaterialApp] — a test, a preview — still renders.
  AppColors get palette =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  /// Built once, not per rebuild.
  static final ThemeData light = _build(AppColors.light, Brightness.light);
  static final ThemeData dark = _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors palette, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: brightness,
        ).copyWith(
          primary: palette.accent,
          surface: palette.cardBackground,
          error: palette.danger.foreground,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.groupedBackground,
      canvasColor: palette.groupedBackground,
      extensions: [palette],
      fontFamily: AppText.family,
      textTheme: AppText.themeFor(palette.label),
      // iOS transitions on every platform, as in Atara: the horizontal slide
      // and the swipe-back gesture are half of what makes the app read as iOS.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // No ripples anywhere: iOS answers a touch by dimming what was touched.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      dividerTheme: DividerThemeData(
        color: palette.separator,
        space: 0,
        thickness: 0.5,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: palette.accent,
        scaffoldBackgroundColor: palette.groupedBackground,
        barBackgroundColor: palette.cardBackground,
        // Every nav-bar style is set, navActionTextStyle included. Left unset
        // it falls back to Cupertino's own `inherit: false` style, and the nav
        // bar's title morph then asserts while lerping two TextStyles with
        // different `inherit` values — a red flash on every push in debug.
        textTheme: CupertinoTextThemeData(
          primaryColor: palette.accent,
          textStyle: AppText.body.copyWith(color: palette.label),
          navTitleTextStyle: AppText.headline.copyWith(color: palette.label),
          navLargeTitleTextStyle: AppText.largeTitle.copyWith(
            color: palette.label,
          ),
          actionTextStyle: AppText.body.copyWith(color: palette.accent),
          navActionTextStyle: AppText.body.copyWith(color: palette.accent),
        ),
      ),
    );
  }
}
