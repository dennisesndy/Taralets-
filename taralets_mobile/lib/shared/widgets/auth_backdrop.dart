import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  Widget _blob(double size) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.55,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.orangeSoft,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(top: -90, right: -70, child: _blob(240)),
        Positioned(bottom: -110, left: -90, child: _blob(280)),
        child,
      ],
    );
  }
}