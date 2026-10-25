import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

/// Typography-only "Taralets!" wordmark in the app's script font.
///
/// Use [onDark] on navy surfaces (white wordmark) and leave it false on light
/// ones (navy wordmark). The shared [heroTag] lets it glide between screens.
/// `emoji` is accepted and ignored so OTP / forgot / reset screens still compile.
class AuthLogo extends StatelessWidget {
  const AuthLogo({
    super.key,
    this.emoji,
    this.size = 100,
    this.onDark = false,
    this.heroTag = AuthLogo.defaultHeroTag,
    this.animate = true,
  });

  static const String defaultHeroTag = 'taralets-logo';

  /// Deprecated, ignored.
  final String? emoji;

  /// 100 -> roughly 44px type.
  final double size;
  final bool onDark;
  final String? heroTag;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.pacifico(
      fontSize: size * 0.44,
    );

    Widget logo = Material(
      type: MaterialType.transparency,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Taralets',
                style: base.copyWith(
                  color: onDark ? Colors.white : AppColors.navy,
                ),
              ),
              TextSpan(
                text: '!',
                style: base.copyWith(color: AppColors.brandOrange),
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );

    if (animate) {
      logo = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        ),
        child: logo,
      );
    }

    return heroTag == null ? logo : Hero(tag: heroTag!, child: logo);
  }
}
