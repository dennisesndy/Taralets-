import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Text styles: Manrope for UI text (clean, geometric, modern) and
/// JetBrains Mono for codes, clocks and ranges. Sizes are in dp.
///
/// `AppText.ui(size, weight, color: ...)` keeps the same signature, so every
/// existing screen picks up the new font automatically.
class AppText {
  AppText._();

  static TextStyle ui(
    double size,
    FontWeight weight, {
    Color color = AppColors.text,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.manrope(
    fontSize: size,
    fontWeight: weight,
    color: color,
    // Large headings look sharper with slightly tighter tracking.
    letterSpacing: letterSpacing ?? _defaultTracking(size),
    height: height ?? _defaultHeight(size),
  );

  /// Big screen titles, e.g. "Explore Manila!".
  static TextStyle display(double size, {Color color = AppColors.navy}) =>
      ui(size, FontWeight.w800, color: color);

  /// Section headings, e.g. "Recommended Places".
  static TextStyle heading(double size, {Color color = AppColors.navy}) =>
      ui(size, FontWeight.w700, color: color);

  static TextStyle mono(
    double size,
    FontWeight weight, {
    Color color = AppColors.text,
    double? letterSpacing,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );

  static double _defaultTracking(double size) {
    if (size >= 24) return -0.6;
    if (size >= 18) return -0.3;
    if (size >= 15) return -0.1;
    return 0;
  }

  static double _defaultHeight(double size) {
    if (size >= 24) return 1.2;
    if (size >= 18) return 1.25;
    return 1.35;
  }
}