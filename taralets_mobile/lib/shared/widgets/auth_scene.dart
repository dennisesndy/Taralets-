import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Soft radial glow used as a decorative blob.
class AuthGlow extends StatelessWidget {
  const AuthGlow({super.key, required this.color, required this.size, this.opacity = 0.25});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(opacity), color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}

/// A looping commute story: a shared transit ride follows a dashed route
/// between stops, with mint route accents and an orange destination pin.
class AuthRouteScene extends StatefulWidget {
  const AuthRouteScene({super.key, this.scale = 1});

  /// 1 for the Welcome screen, ~0.7 for the compact login/register header.
  final double scale;

  @override
  State<AuthRouteScene> createState() => _AuthRouteSceneState();
}

class _AuthRouteSceneState extends State<AuthRouteScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static Path _route(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.07, h * 0.80)
      ..cubicTo(w * 0.30, h * 0.30, w * 0.50, h * 0.98, w * 0.90, h * 0.30);
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          final metric = _route(size).computeMetrics().first;

          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              final p = v < 0.8 ? Curves.easeInOutCubic.transform(v / 0.8) : 1.0;
              final fade = v < 0.04
                  ? v / 0.04
                  : (v > 0.93 ? 1 - (v - 0.93) / 0.07 : 1.0);
              final tan = metric.getTangentForOffset(metric.length * p)!;
              final angle = tan.vector.direction + math.pi / 2;
              final planeSize = 30.0 * scale;

              return Opacity(
                opacity: fade.clamp(0.0, 1.0).toDouble(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ScenePainter(
                          metric: metric,
                          progress: p,
                          t: v,
                          scale: scale,
                        ),
                      ),
                    ),
                    Positioned(
                      left: tan.position.dx - planeSize / 2,
                      top: tan.position.dy - planeSize / 2,
                      child: Transform.rotate(
                        angle: angle,
                        child: Icon(
                          Icons.directions_bus_rounded,
                          size: planeSize * 1.08,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: AppColors.navy.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.metric,
    required this.progress,
    required this.t,
    required this.scale,
  });

  final PathMetric metric;
  final double progress;
  final double t;
  final double scale;

  double _pop(double x) =>
      x <= 0 ? 0 : (x >= 1 ? 1 : Curves.easeOutBack.transform(x));

  void _icon(Canvas c, IconData icon, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _clouds(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.07);
    const bases = [0.10, 0.55, 0.85];
    const ys = [0.06, 0.58, 0.34];
    for (var i = 0; i < 3; i++) {
      final x = (((bases[i] + t * 1.4) % 1.4) - 0.2) * size.width;
      final y = ys[i] * size.height;
      final w = (54 + i * 12) * scale;
      final h = 14 * scale;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: w, height: h),
          Radius.circular(h / 2),
        ),
        paint,
      );
      canvas.drawCircle(Offset(x - w * 0.12, y - h * 0.55), h * 0.8, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _clouds(canvas, size);
    final len = metric.length;

    // dashed full route
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2 * scale
      ..color = Colors.white.withOpacity(0.28);
    final step = 14 * scale + 4;
    for (double d = 0; d < len; d += step) {
      canvas.drawPath(metric.extractPath(d, math.min(d + 7 * scale + 1, len)), dash);
    }

    // mint contrail
    if (progress > 0.002) {
      final trail = metric.extractPath(0, len * progress);
      canvas.drawPath(
        trail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 9 * scale
          ..color = AppColors.brandMint.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        trail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.2 * scale
          ..color = AppColors.brandMint,
      );
    }

    // start dot
    final start = metric.getTangentForOffset(0)!.position;
    canvas.drawCircle(start, 9 * scale, Paint()..color = AppColors.brandMint.withOpacity(0.25));
    canvas.drawCircle(start, 5 * scale, Paint()..color = AppColors.brandMint);

    // mid stop
    final mid = metric.getTangentForOffset(len * 0.5)!.position;
    final m = _pop((progress - 0.5) / 0.08);
    if (m > 0) {
      canvas.drawCircle(mid, 9 * scale * m, Paint()..color = Colors.white);
      canvas.drawCircle(mid, 6.5 * scale * m, Paint()..color = AppColors.brandOrange);
    }

    // destination pin + ripple
    final end = metric.getTangentForOffset(len)!.position;
    final d = _pop((progress - 0.9) / 0.1);
    if (d > 0) {
      final r = (t * 3) % 1;
      canvas.drawCircle(
        end,
        (8 + 22 * r) * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * scale
          ..color = AppColors.brandMint.withOpacity((1 - r) * 0.7),
      );
      final pin = 36 * scale * d;
      final c = end - Offset(0, pin * 0.42);
      _icon(canvas, Icons.location_on, c, pin + 5 * scale, Colors.white);
      _icon(canvas, Icons.location_on, c, pin, AppColors.brandOrange);
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => true;
}