import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';

const Map<String, Color> _avatarColors = {
  'Dennise': AppColors.orange,
  'Ana': AppColors.navy,
  'Paola': AppColors.purple,
  'Jewelle': AppColors.green,
};

/// Figma Avatar: round, white bold initials (first two letters of the name).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = _avatarColors[name] ?? AppColors.muted;
    final initials = name.length >= 2 ? name.substring(0, 2) : name;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: AppText.ui(size * 0.33, FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// Overlapping avatar row (-8 overlap, 2px ring), as used on Home / Join Trip.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.names,
    required this.size,
    required this.ringColor,
  });

  final List<String> names;
  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size + 4,
      width: names.length * (size + 4) - (names.length - 1) * 8,
      child: Stack(
        children: [
          for (var i = 0; i < names.length; i++)
            Positioned(
              left: i * (size + 4 - 8),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: ringColor,
                  shape: BoxShape.circle,
                ),
                child: Avatar(name: names[i], size: size),
              ),
            ),
        ],
      ),
    );
  }
}
