import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'auth_scene.dart';

/// Light off-white scaffold with two very soft brand glows. Used by every
/// auth screen (including OTP / forgot / reset, whose API is unchanged).
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            bottom: -150,
            right: -130,
            child: AuthGlow(color: AppColors.brandMint, size: 340, opacity: 0.16),
          ),
          const Positioned(
            bottom: -170,
            left: -140,
            child: AuthGlow(color: AppColors.brandOrange, size: 340, opacity: 0.09),
          ),
          child,
        ],
      ),
    );
  }
}