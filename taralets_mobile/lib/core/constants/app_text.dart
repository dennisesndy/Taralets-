import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Text styles matching the Figma Make CSS: Plus Jakarta Sans for UI text and
/// JetBrains Mono for codes, clocks and ranges. Sizes are in dp (Figma px).
class AppText {
  AppText._();

  static TextStyle ui(
    double size,
    FontWeight weight, {
    Color color = AppColors.text,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

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
}
