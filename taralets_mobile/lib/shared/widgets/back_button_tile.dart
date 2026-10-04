import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'app_icons.dart';

/// Figma BackBtn: 40x40, white, radius 12, 1.5px border.
class BackButtonTile extends StatelessWidget {
  const BackButtonTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: AppIcons.back(),
      ),
    );
  }
}
