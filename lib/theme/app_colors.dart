import 'package:flutter/material.dart';

/// A foreground/background pair carrying one meaning.
///
/// Passing the pair around keeps the two halves together: a caller cannot pick
/// a warning background and then colour the text with the danger foreground.
@immutable
class ToneColors {
  const ToneColors({
    required this.foreground,
    required this.background,
    required this.onBackground,
  });

  /// For icons and emphasised text on the page's own surface.
  final Color foreground;

  /// For the fill behind a banner or badge.
  final Color background;

  /// For text and icons sitting on [background].
  final Color onBackground;

  ToneColors lerpTo(ToneColors other, double t) {
    return ToneColors(
      foreground: Color.lerp(foreground, other.foreground, t)!,
      background: Color.lerp(background, other.background, t)!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
    );
  }
}

/// The app's palette, in both appearances.
///
/// Built on the same structure as Atara's palette — a gradient header, soft
/// white cards on a tinted page, pill buttons — but recoloured for water: deep
/// navy in the top-left corner of every hero surface, running out to a clear
/// cyan at the far edge, on a cool off-white page.
///
/// Every colour is defined for both appearances in one place, so a new surface
/// cannot be added in light and forgotten in dark.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.groupedBackground,
    required this.cardBackground,
    required this.separator,
    required this.fill,
    required this.field,
    required this.heroStart,
    required this.heroMid,
    required this.heroEnd,
    required this.heroSheen,
    required this.heroShadow,
    required this.onHero,
    required this.primaryGradientStart,
    required this.primaryGradientEnd,
    required this.waterTop,
    required this.waterBottom,
  });

  /// The brand blue for text and icons: links, ticks, the active tab. Dark
  /// enough in light to read as text on the page (>= 4.5:1).
  final Color accent;

  /// What sits on a filled button: white in both appearances.
  final Color onAccent;

  /// Normal level.
  final ToneColors success;

  /// Close to a threshold, or a soft problem.
  final ToneColors warning;

  /// Empty tank, or a connection that failed.
  final ToneColors danger;

  /// Full tank.
  final ToneColors info;

  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;

  /// The page itself, behind the cards.
  final Color groupedBackground;

  /// The cards that carry almost every row.
  final Color cardBackground;

  /// Hairline rules between rows.
  final Color separator;

  /// Untinted chips and badges, and the press tint on a row.
  final Color fill;

  /// The inside of a text box.
  final Color field;

  /// The hero header: deep navy at the top-left corner…
  final Color heroStart;

  /// …through an ocean blue…
  final Color heroMid;

  /// …out to cyan at the bottom-right.
  final Color heroEnd;

  /// A white highlight at low alpha, fading out by 55%.
  final Color heroSheen;

  /// The soft lift under a card floating over the header.
  final Color heroShadow;

  /// What sits on the header: white in both appearances.
  final Color onHero;

  /// The two stops of the primary button, left to right.
  final Color primaryGradientStart;
  final Color primaryGradientEnd;

  /// The water inside the tank gauge, surface to floor.
  final Color waterTop;
  final Color waterBottom;

  static const light = AppColors(
    accent: Color(0xFF0B63C1),
    onAccent: Color(0xFFFFFFFF),
    success: ToneColors(
      foreground: Color(0xFF16833A),
      background: Color(0xFFDDF5E4),
      onBackground: Color(0xFF0F5A28),
    ),
    warning: ToneColors(
      foreground: Color(0xFFE17100),
      background: Color(0xFFFEF3C6),
      onBackground: Color(0xFF973C00),
    ),
    danger: ToneColors(
      foreground: Color(0xFFDC2626),
      background: Color(0x1ADC2626),
      onBackground: Color(0xFFC81E1E),
    ),
    info: ToneColors(
      foreground: Color(0xFF0B63C1),
      background: Color(0xFFDCEBFF),
      onBackground: Color(0xFF0A4A92),
    ),
    label: Color(0xFF0F1A2A),
    secondaryLabel: Color(0xFF586579),
    tertiaryLabel: Color(0xFF9DA8B8),
    groupedBackground: Color(0xFFEEF3F9),
    cardBackground: Color(0xFFFFFFFF),
    separator: Color(0xFFDEE5EE),
    fill: Color(0xFFEEF3F9),
    field: Color(0xFFE7EDF5),
    heroStart: Color(0xFF0A2350),
    heroMid: Color(0xFF0F5BB5),
    heroEnd: Color(0xFF22B4E6),
    heroSheen: Color(0x24FFFFFF),
    heroShadow: Color(0x1F0A2350),
    onHero: Color(0xFFFFFFFF),
    primaryGradientStart: Color(0xFF0A2E66),
    primaryGradientEnd: Color(0xFF1677D2),
    waterTop: Color(0xFF8BE3FF),
    waterBottom: Color(0xFF3AA8F0),
  );

  static const dark = AppColors(
    accent: Color(0xFF5FB4FF),
    onAccent: Color(0xFFFFFFFF),
    success: ToneColors(
      foreground: Color(0xFF5ED38A),
      background: Color(0x2634C26A),
      onBackground: Color(0xFF7FE0A3),
    ),
    warning: ToneColors(
      foreground: Color(0xFFFFB900),
      background: Color(0x26FE9A00),
      onBackground: Color(0xFFFFB900),
    ),
    danger: ToneColors(
      foreground: Color(0xFFFF6467),
      background: Color(0x33FF6467),
      onBackground: Color(0xFFFF6467),
    ),
    info: ToneColors(
      foreground: Color(0xFF5FB4FF),
      background: Color(0x262F8CFF),
      onBackground: Color(0xFF7CC3FF),
    ),
    label: Color(0xFFF0F4FA),
    secondaryLabel: Color(0xFFA0ABBC),
    tertiaryLabel: Color(0xFF677385),
    groupedBackground: Color(0xFF080D15),
    cardBackground: Color(0xFF111924),
    separator: Color(0x1AFFFFFF),
    fill: Color(0xFF1A2432),
    field: Color(0xFF1C2838),
    heroStart: Color(0xFF051530),
    heroMid: Color(0xFF0B3F80),
    heroEnd: Color(0xFF137FB3),
    heroSheen: Color(0x1AFFFFFF),
    heroShadow: Color(0x8C000000),
    onHero: Color(0xFFFFFFFF),
    primaryGradientStart: Color(0xFF07214A),
    primaryGradientEnd: Color(0xFF1468B8),
    waterTop: Color(0xFF6CD3F5),
    waterBottom: Color(0xFF1F86CC),
  );

  /// The tint behind icon tiles and other quiet accent grounds.
  Color get accentTint => accent.withValues(alpha: 0.10);

  /// The primary button: navy on the left into blue on the right.
  LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryGradientStart, primaryGradientEnd],
  );

  /// The hero header: a diagonal from the top-left corner.
  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroStart, heroMid, heroEnd],
    stops: const [0.0, 0.5, 1.0],
  );

  /// A highlight laid over the header so it does not read as flat paint.
  ///
  /// The fade is [heroSheen] at zero alpha, never `Colors.transparent` — that
  /// constant is transparent *black*, which darkens the middle.
  ///
  /// It fades over the whole diagonal. Reaching zero alpha anywhere inside
  /// the header (Atara's ends at 0.55) makes Impeller draw a bright
  /// one-pixel line across it at exactly that point.
  LinearGradient get heroSheenGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [heroSheen, heroSheen.withValues(alpha: 0)],
  );

  /// The water in the gauge, surface to floor.
  LinearGradient get waterGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [waterTop, waterBottom],
  );

  /// The one soft lift: a card floating over the header.
  List<BoxShadow> get heroShadows => [
    BoxShadow(color: heroShadow, blurRadius: 24, offset: const Offset(0, 10)),
  ];

  @override
  AppColors copyWith({
    Color? accent,
    Color? onAccent,
    ToneColors? success,
    ToneColors? warning,
    ToneColors? danger,
    ToneColors? info,
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
    Color? groupedBackground,
    Color? cardBackground,
    Color? separator,
    Color? fill,
    Color? field,
    Color? heroStart,
    Color? heroMid,
    Color? heroEnd,
    Color? heroSheen,
    Color? heroShadow,
    Color? onHero,
    Color? primaryGradientStart,
    Color? primaryGradientEnd,
    Color? waterTop,
    Color? waterBottom,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      label: label ?? this.label,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
      groupedBackground: groupedBackground ?? this.groupedBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      separator: separator ?? this.separator,
      fill: fill ?? this.fill,
      field: field ?? this.field,
      heroStart: heroStart ?? this.heroStart,
      heroMid: heroMid ?? this.heroMid,
      heroEnd: heroEnd ?? this.heroEnd,
      heroSheen: heroSheen ?? this.heroSheen,
      heroShadow: heroShadow ?? this.heroShadow,
      onHero: onHero ?? this.onHero,
      primaryGradientStart: primaryGradientStart ?? this.primaryGradientStart,
      primaryGradientEnd: primaryGradientEnd ?? this.primaryGradientEnd,
      waterTop: waterTop ?? this.waterTop,
      waterBottom: waterBottom ?? this.waterBottom,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: success.lerpTo(other.success, t),
      warning: warning.lerpTo(other.warning, t),
      danger: danger.lerpTo(other.danger, t),
      info: info.lerpTo(other.info, t),
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
      groupedBackground: Color.lerp(
        groupedBackground,
        other.groupedBackground,
        t,
      )!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      field: Color.lerp(field, other.field, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroMid: Color.lerp(heroMid, other.heroMid, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      heroSheen: Color.lerp(heroSheen, other.heroSheen, t)!,
      heroShadow: Color.lerp(heroShadow, other.heroShadow, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      primaryGradientStart: Color.lerp(
        primaryGradientStart,
        other.primaryGradientStart,
        t,
      )!,
      primaryGradientEnd: Color.lerp(
        primaryGradientEnd,
        other.primaryGradientEnd,
        t,
      )!,
      waterTop: Color.lerp(waterTop, other.waterTop, t)!,
      waterBottom: Color.lerp(waterBottom, other.waterBottom, t)!,
    );
  }
}
