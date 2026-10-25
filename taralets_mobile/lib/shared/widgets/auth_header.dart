import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'auth_clipper.dart';
import 'auth_logo.dart';
import 'auth_scene.dart';

/// Curved navy header for Login / Register: logo, a mini flight-path scene,
/// and an optional [leading] widget (e.g. a back button).
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.height = 260, this.leading, this.logoSize = 88});

  final double height;
  final Widget? leading;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipPath(
        clipper: const AuthCurveClipper(depth: 0.12, lowPoint: 0.6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.navy),
            const Positioned(
              top: -90,
              right: -70,
              child: AuthGlow(color: AppColors.brandMint, size: 240, opacity: 0.22),
            ),
            const Positioned(
              bottom: -60,
              left: -80,
              child: AuthGlow(color: AppColors.brandOrange, size: 240, opacity: 0.28),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: height * 0.16,
              height: height * 0.36,
              child: const AuthRouteScene(scale: 0.7),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(height: 44, child: leading),
                    ),
                    const SizedBox(height: 4),
                    AuthLogo(size: logoSize, onDark: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}