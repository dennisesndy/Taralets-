import 'package:flutter/material.dart';

/// Clips the bottom edge of the hero image into a deep, asymmetrical U-curve.
/// The low point sits right of centre so the curve feels organic, not a
/// perfect semicircle.
class AuthCurveClipper extends CustomClipper<Path> {
  const AuthCurveClipper({this.depth = 0.16, this.lowPoint = 0.58});

  /// How far the curve dips, as a fraction of height.
  final double depth;

  /// Horizontal position (0..1) of the lowest point of the U.
  final double lowPoint;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final sideY = h * (1 - depth); // where the curve leaves the left/right edge
    final bottomX = w * lowPoint;

    final path = Path()
      ..lineTo(0, sideY)
      // left side sweeps down to the low point
      ..cubicTo(w * 0.04, h * 0.99, bottomX - w * 0.22, h, bottomX, h)
      // right side lifts back up, a little steeper
      ..cubicTo(bottomX + w * 0.26, h, w * 0.98, h * 0.96, w, sideY - h * 0.03)
      ..lineTo(w, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant AuthCurveClipper old) =>
      old.depth != depth || old.lowPoint != lowPoint;
}