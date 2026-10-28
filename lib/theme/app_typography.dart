import 'package:flutter/material.dart';

/// The type scale, on Plus Jakarta Sans — the same eight steps Atara uses, so
/// the two apps share a hierarchy.
///
/// The bundled faces are SUBSET (copied from Atara). They cover Latin, digits
/// and a few symbols such as `°`, `³`, `·` and `–`, but not arrows or maths
/// signs like `≥` — write "90% ke atas", not "≥ 90%".
abstract final class AppText {
  static const String family = 'PlusJakartaSans';

  /// Endpoint addresses and raw values.
  static const String monoFamily = 'monospace';

  /// The big level reading on the dashboard.
  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 48,
    height: 52 / 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
  );

  static const TextStyle largeTitle = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const TextStyle title1 = TextStyle(
    fontFamily: family,
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: family,
    fontSize: 21,
    height: 27 / 21,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// Row titles and section headings.
  static const TextStyle headline = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// The default.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  static const TextStyle subhead = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  /// Help lines, timestamps, card subtitles.
  static const TextStyle footnote = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// Maps the scale onto the slots Flutter's own widgets read, so a stray
  /// `Text` with no explicit style still lands somewhere sensible.
  static TextTheme themeFor(Color label) {
    return TextTheme(
      displayLarge: largeTitle.copyWith(color: label),
      headlineLarge: largeTitle.copyWith(color: label),
      headlineMedium: title1.copyWith(color: label),
      headlineSmall: title2.copyWith(color: label),
      titleLarge: title2.copyWith(color: label),
      titleMedium: headline.copyWith(color: label),
      titleSmall: headline.copyWith(color: label),
      bodyLarge: body.copyWith(color: label),
      bodyMedium: body.copyWith(color: label),
      bodySmall: footnote.copyWith(color: label),
      labelLarge: headline.copyWith(color: label),
      labelMedium: subhead.copyWith(color: label),
      labelSmall: caption.copyWith(color: label),
    );
  }
}
