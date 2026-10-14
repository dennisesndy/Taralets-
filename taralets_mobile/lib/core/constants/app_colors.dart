import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand (Rose Primary)
  // ---------------------------------------------------------------------------
  static const Color navy = Color(0xFF1B2B4B); // headings / strong text
  static const Color primary = Color(0xFFF43F5E); // main accent (Rose)
  static const Color primaryLight = Color(0xFFFB7185); // gradient end
  static const Color primarySoft = Color(0xFFFFE4E6); // tinted pills / tiles
  static const Color gold = Color(0xFFF2C14E); // ratings / stars

  // ---------------------------------------------------------------------------
  // Legacy aliases.
  // Nakaturo na ngayon ang mga orange variables sa bagong Rose primary
  // para hindi mag-error ang ibang screens.
  // ---------------------------------------------------------------------------
  static const Color orange = primary; 
  static const Color orangeLight = primaryLight; 
  static const Color orangeSoft = primarySoft;

  // ---------------------------------------------------------------------------
  // Neutrals (white-first)
  // ---------------------------------------------------------------------------
  static const Color bg = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1F2937);
  static const Color muted = Color(0xFF6B7280);
  static const Color border = Color(0xFFEBEEF3);
  static const Color navDivider = Color(0xFFF3F4F6);
  static const Color navInactive = Color(0xFFC3CAD6);
  static const Color placeholder = Color(0xFF9CA3AF);

  // ---------------------------------------------------------------------------
  // Status (softened so nothing looks harsh next to photos)
  // ---------------------------------------------------------------------------
  static const Color green = Color(0xFF34B27B);
  static const Color red = Color(0xFFE5484D);
  static const Color amber = Color(0xFFF2B84B);
  static const Color indigo = Color(0xFF6366F1);
  static const Color purple = Color(0xFF8B5CF6);

  // Soft tints used for pills / icon tiles
  static const Color blueSoft = Color(0xFFEEF4FE); // Keep this pure blue for icons
  static const Color greenSoft = Color(0xFFE6F7EF);
  static const Color greenText = Color(0xFF0F6B4A);
  static const Color greenDeep = Color(0xFF0B8A5E);
  static const Color amberSoft = Color(0xFFFFF6DE);
  static const Color amberText = Color(0xFF8A5A12);
  static const Color redSoft = Color(0xFFFDEDEE);

  // Error note
  static const Color errorBg = Color(0xFFFEF3F3);
  static const Color errorBorder = Color(0xFFF9CFD1);
  static const Color errorTitle = Color(0xFF9B2C30);
  static const Color errorBody = Color(0xFFB4383D);

  // Map (index.css .map-bg / .water)
  static const Color mapBg = Color(0xFFDCE8F2);
  static const Color water = Color(0xFFB4D0E4);
}