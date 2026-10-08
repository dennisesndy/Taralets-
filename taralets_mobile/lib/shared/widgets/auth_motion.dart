import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';

/// Fade + slide-up entrance. Use `delay` to stagger children.
class AuthReveal extends StatefulWidget {
  const AuthReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<AuthReveal> createState() => _AuthRevealState();
}

class _AuthRevealState extends State<AuthReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offset),
          child: child,
        ),
      ),
    );
  }
}

/// Horizontal shake. Call `key.currentState?.shake()`.
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({super.key, required this.child});
  final Widget child;

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  void shake() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final dx = math.sin(_c.value * math.pi * 6) * 8 * (1 - _c.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// Slow, subtle up-and-down float for the hero logo.
class FloatingBadge extends StatefulWidget {
  const FloatingBadge({super.key, required this.child});
  final Widget child;

  @override
  State<FloatingBadge> createState() => _FloatingBadgeState();
}

class _FloatingBadgeState extends State<FloatingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -6 * _curve.value),
        child: child,
      ),
    );
  }
}

/// "STEP 1 OF 2" progress bar shared by the recovery flow.
class AuthStepper extends StatelessWidget {
  const AuthStepper({
    super.key,
    required this.step,
    required this.label,
    this.total = 2,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP $step OF $total  ·  $label'.toUpperCase(),
          style: AppText.ui(11, FontWeight.w800, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 5,
                      color: AppColors.border,
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: i < step ? 1 : 0),
                        duration: Duration(milliseconds: 500 + i * 150),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => FractionallySizedBox(
                          widthFactor: v,
                          child: Container(color: AppColors.orange),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}