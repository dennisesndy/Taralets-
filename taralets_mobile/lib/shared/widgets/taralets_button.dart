import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';

enum _Kind { orange, navy, ghost }

/// The three Figma buttons: OrangeBtn (gradient + glow), NavyBtn, GhostBtn.
class TaraletsButton extends StatelessWidget {
  const TaraletsButton.orange({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.full = true,
    this.small = false,
    this.isLoading = false,
  }) : _kind = _Kind.orange;

  const TaraletsButton.navy({
    super.key,
    required this.label,
    required this.onPressed,
    this.full = true,
    this.isLoading = false,
  }) : _kind = _Kind.navy,
       icon = null,
       small = false;

  const TaraletsButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.full = true,
  }) : _kind = _Kind.ghost,
       icon = null,
       small = false,
       isLoading = false;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool full;
  final bool small;
  final bool isLoading;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final isOrange = _kind == _Kind.orange;
    final isGhost = _kind == _Kind.ghost;

    final fg = isGhost ? AppColors.text : Colors.white;
    final fontSize = small ? 13.0 : 15.0;
    final weight = isGhost ? FontWeight.w600 : FontWeight.w700;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: isOrange
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.orange, AppColors.orangeLight],
            )
          : null,
      color: isOrange ? null : (isGhost ? Colors.white : AppColors.navy),
      border: isGhost ? Border.all(color: AppColors.border, width: 1.5) : null,
      boxShadow: isOrange
          ? [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );

    final padding = EdgeInsets.symmetric(
      horizontal: small ? 20 : 24,
      vertical: isGhost ? 14 : (small ? 11 : 15),
    );

    final content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(fontSize, weight, color: fg),
                ),
              ),
            ],
          );

    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLoading ? null : onPressed,
      child: Container(
        decoration: decoration,
        padding: padding,
        alignment: Alignment.center,
        child: content,
      ),
    );

    return full ? SizedBox(width: double.infinity, child: button) : button;
  }
}
