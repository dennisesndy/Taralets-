import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Figma `.map-bg` with `.road-h`, `.road-v`, `.road-h-sm` and `.water`,
/// used by the Create Trip meetup step.
class MapBackground extends StatelessWidget {
  const MapBackground({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _Painter(), size: Size.infinite);
}

class _Painter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.mapBg);

    void grid(double step, Color color) {
      final p = Paint()
        ..color = color
        ..strokeWidth = 1;
      for (double x = 0; x <= size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    }

    grid(18, const Color(0x40B4C8D7));
    grid(72, const Color(0x8CFFFFFF));

    final road = Paint()..color = const Color(0xD9FFFFFF);
    void bar(Rect r) => canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(4)),
      road,
    );

    bar(Rect.fromLTWH(0, size.height * 0.5, size.width, 7)); // road-h
    bar(Rect.fromLTWH(size.width * 0.45, 0, 7, size.height)); // road-v
    bar(
      Rect.fromLTWH(size.width * 0.2, size.height * 0.3, size.width * 0.6, 4),
    ); // road-h-sm

    // Manila Bay: 55dp wide, right side rounded.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, 55, size.height),
        topRight: const Radius.elliptical(33, 108),
        bottomRight: const Radius.elliptical(33, 108),
      ),
      Paint()..color = AppColors.water,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
