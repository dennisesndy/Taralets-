import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../shared/widgets/auth_button.dart';
import '../../../../shared/widgets/auth_clipper.dart';
import '../../../../shared/widgets/auth_logo.dart';
import '../../../../shared/widgets/auth_scene.dart';
import '../../../../shared/widgets/fade_slide_in.dart';

/// Welcome screen. No timer; the only automatic navigation is the saved-token
/// check, so signed-in users still go straight to Home.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.getToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final heroH = (h * 0.58).clamp(280.0, 520.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            // ── Hero: navy sky with the animated flight path ──
            SizedBox(
              height: heroH,
              width: double.infinity,
              child: ClipPath(
                clipper: const AuthCurveClipper(depth: 0.09, lowPoint: 0.6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: AppColors.navy),
                    const Positioned(
                      top: -80,
                      right: -60,
                      child: AuthGlow(color: AppColors.brandMint, size: 280, opacity: 0.22),
                    ),
                    const Positioned(
                      bottom: -40,
                      left: -90,
                      child: AuthGlow(color: AppColors.brandOrange, size: 280, opacity: 0.28),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: heroH * 0.13,
                      height: heroH * 0.46,
                      child: const AuthRouteScene(),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, heroH * 0.06, 24, 0),
                        child: Column(
                          children: [
                            const AuthLogo(size: 125, onDark: true),
                            const SizedBox(height: 14),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 350),
                              child: const _TaglineChip(),
                            ),
                            const SizedBox(height: 18),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 500),
                              child: const _CrewAvatars(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Actions ──
            SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 450),
                        child: Text(
                          'Where to next?',
                          textAlign: TextAlign.center,
                          style: AppText.ui(24, FontWeight.w900, color: AppColors.navy),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 520),
                        child: Text(
                          'Start a trip with your crew, or pick up where you left off.',
                          textAlign: TextAlign.center,
                          style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 620),
                        child: _WelcomeButton(
                          label: 'Sign Up',
                          filled: true,
                          onTap: () => context.push(AppRoutes.register),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 740),
                        child: _WelcomeButton(
                          label: 'Log In',
                          filled: false,
                          onTap: () => context.push(AppRoutes.login),
                        ),
                      ),
                    ],
                  ),
                ),
            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaglineChip extends StatelessWidget {
  const _TaglineChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: AppColors.brandMint, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'Plan together. Arrive together.',
            style: AppText.ui(12, FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _CrewAvatars extends StatelessWidget {
  const _CrewAvatars();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.brandOrange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'MADE FOR THE WHOLE CREW',
            style: AppText.ui(10, FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final fg = filled ? Colors.white : AppColors.navy;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: filled
            ? [
                BoxShadow(
                  color: AppColors.brandOrange.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: filled ? AppColors.brandOrange : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.navy, width: filled ? 0 : 1.6),
        ),
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppText.ui(16, FontWeight.w800, color: fg)),
              if (filled) ...[
                const SizedBox(width: 8),
                const MintArrowChip(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
