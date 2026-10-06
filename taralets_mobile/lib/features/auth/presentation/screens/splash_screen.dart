import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/fade_slide_in.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  late final Animation<double> _logoScale =
      CurvedAnimation(parent: _intro, curve: Curves.elasticOut);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2800), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    // TODO: kapag may saved token na, i-redirect sa AppRoutes.home.
    context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  Widget _ring(double phase) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        final t = (_loop.value + phase) % 1.0;
        final size = 120 + 120 * t;
        return Opacity(
          opacity: (1 - t) * 0.5,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.orange,
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _ring(0),
                        _ring(0.5),
                        ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: 112,
                            height: 112,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26000000),
                                  blurRadius: 30,
                                  offset: Offset(0, 14),
                                ),
                              ],
                            ),
                            child: const Text('✈️', style: TextStyle(fontSize: 56)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 500),
                    child: Text(
                      'Taralets',
                      style: AppText.ui(40, FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 750),
                    child: Text(
                      'Plan trips. Travel together.',
                      style: AppText.ui(14, FontWeight.w500, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: Center(child: _LoadingDots(animation: _loop)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (animation.value * 2 * math.pi) - i * 0.9;
            final opacity = 0.3 + 0.7 * ((math.sin(phase) + 1) / 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}