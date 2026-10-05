import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';
import 'app_icons.dart';

/// Figma `.pref-card` (+ `.selected`): 2dp border, 12dp radius, 12dp padding,
/// 24sp emoji over a 12sp/600 label, orange check badge when selected.
class PrefCard extends StatelessWidget {
  const PrefCard({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.orangeSoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: 2,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppText.ui(
                      12,
                      FontWeight.w600,
                      color: selected ? AppColors.orange : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppIcons.check(size: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
