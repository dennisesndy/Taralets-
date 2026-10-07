import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_colors.dart';

/// The exact SVG icons from the Figma Make file (`const Icon` in App.tsx),
/// drawn with flutter_svg so stroke widths and shapes match pixel for pixel.
class AppIcons {
  AppIcons._();

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Widget _stroke(
    String inner,
    Color c,
    double size, {
    double sw = 2,
    String fill = 'none',
  }) {
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="$fill" stroke="${_hex(c)}" stroke-opacity="${c.a}" '
        'stroke-width="$sw" stroke-linecap="round" stroke-linejoin="round">$inner</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }

  static Widget _fill(String inner, Color c, double size) {
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="${_hex(c)}" fill-opacity="${c.a}">$inner</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }

  // --- bottom navigation -------------------------------------------------
  static Widget home({Color color = AppColors.muted, double size = 22}) =>
      _stroke(
        '<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
        '<polyline points="9 22 9 12 15 12 15 22"/>',
        color,
        size,
      );

  static Widget compass({
    Color color = AppColors.muted,
    double size = 22,
  }) => _stroke(
    '<circle cx="12" cy="12" r="10"/>'
    '<polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/>',
    color,
    size,
  );

  static Widget map({
    Color color = AppColors.muted,
    double size = 22,
  }) => _stroke(
    '<polygon points="1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6"/>'
    '<line x1="8" y1="2" x2="8" y2="18"/><line x1="16" y1="6" x2="16" y2="22"/>',
    color,
    size,
  );

  static Widget calendar({
    Color color = AppColors.muted,
    double size = 22,
  }) => _stroke(
    '<rect x="3" y="4" width="18" height="18" rx="2"/>'
    '<line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>'
    '<line x1="3" y1="10" x2="21" y2="10"/>',
    color,
    size,
  );

  static Widget user({Color color = AppColors.muted, double size = 22}) =>
      _stroke(
        '<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>'
        '<circle cx="12" cy="7" r="4"/>',
        color,
        size,
      );

  // --- general -----------------------------------------------------------
  static Widget back({Color color = AppColors.text, double size = 20}) =>
      _stroke('<path d="M19 12H5M12 5l-7 7 7 7"/>', color, size, sw: 2.2);

  static Widget pin({
    Color color = AppColors.orange,
    double size = 16,
  }) => _fill(
    '<path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>',
    color,
    size,
  );

  static Widget clock({Color color = AppColors.muted, double size = 14}) =>
      _stroke(
        '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
        color,
        size,
      );

  static Widget star({Color color = AppColors.gold, double size = 13}) => _fill(
    '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>',
    color,
    size,
  );

  static Widget check({Color color = Colors.white, double size = 16}) =>
      _stroke('<polyline points="20 6 9 17 4 12"/>', color, size, sw: 2.5);

  static Widget plus({Color color = Colors.white, double size = 20}) => _stroke(
    '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>',
    color,
    size,
    sw: 2.5,
  );

  static Widget alert({
    Color color = AppColors.amber,
    double size = 16,
  }) => _stroke(
    '<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>'
    '<line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
    color,
    size,
  );

  static Widget chevronRight({
    Color color = AppColors.muted,
    double size = 16,
  }) => _stroke('<polyline points="9 18 15 12 9 6"/>', color, size, sw: 2.2);

  static Widget users({
    Color color = AppColors.muted,
    double size = 16,
  }) => _stroke(
    '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>'
    '<path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
    color,
    size,
  );

  static Widget heart({
    bool filled = false,
    Color color = AppColors.muted,
    double size = 16,
  }) => _stroke(
    '<path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>',
    color,
    size,
    fill: filled ? _hex(color) : 'none',
  );

  static Widget search({
    Color color = AppColors.muted,
    double size = 18,
  }) => _stroke(
    '<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>',
    color,
    size,
  );

  static Widget logOut({
    Color color = AppColors.red,
    double size = 18,
  }) => _stroke(
    '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/>'
    '<line x1="21" y1="12" x2="9" y2="12"/>',
    color,
    size,
  );
  static const IconData edit = Icons.edit_outlined; // o Icons.edit
}
