import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// White rounded surface with the soft Figma shadow
/// (`0 1px 6px rgba(0,0,0,0.05)` by default).
class TaraletsCard extends StatelessWidget {
  const TaraletsCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.radius = 14,
    this.blur = 6,
    this.shadowAlpha = 0.05,
    this.border,
    this.clip = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double shadowAlpha;
  final BoxBorder? border;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowAlpha),
            blurRadius: blur,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: box,
    );
  }
}
