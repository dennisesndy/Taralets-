import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFF7F7F5),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Preload the Figma fonts so the first frame doesn't flash a fallback font.
  // Never block startup for long (e.g. when offline).
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
      GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w500),
      GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700),
      GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900),
    ]).timeout(const Duration(seconds: 3));
  } catch (_) {
    // Fall back to the default font; the app still works.
  }

  runApp(const ProviderScope(child: TaraletsApp()));
}
