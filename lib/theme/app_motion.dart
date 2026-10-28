import 'package:flutter/widgets.dart';

/// One set of speeds and curves for the whole app, taken from Atara.
abstract final class AppMotion {
  /// Crossfades, a label swapping for a spinner, a toast.
  static const Duration fast = Duration(milliseconds: 180);

  /// A section or card revealing itself.
  static const Duration base = Duration(milliseconds: 320);

  /// The water level gliding to a new reading.
  static const Duration slow = Duration(milliseconds: 650);

  /// How far behind the previous element the next one starts.
  static const Duration stagger = Duration(milliseconds: 60);

  /// How far a revealed element travels, in logical pixels.
  static const double rise = 16;

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve move = Curves.easeInOutCubic;

  /// Whether movement should be dropped.
  ///
  /// With animations disabled nothing travels, scales or waves — but fades
  /// keep their timing.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
