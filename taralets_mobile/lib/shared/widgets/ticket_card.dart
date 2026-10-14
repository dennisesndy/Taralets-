import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';

/// Soft pastel palette used by the ticket components.
/// Kept local so no existing AppColors values are touched.
class TicketPalette {
  TicketPalette._();
  
  static const redFill = Color(0xFFFFF8F8);
  static const redLine = Color(0xFFF1A9AC);
  static const redText = Color(0xFFD9484D);
  
  // BINAGO: Mas matingkad at lutang na asul para sa Upcoming/Active Trip card
  static const skyFill = Color(0xFFEBF4FF); 
  static const skyLine = Color(0xFF60A5FA); 
  static const skyText = Color(0xFF2563EB);
  
  static const lavenderFill = Color(0xFFF0F5FF);
  static const lavenderLine = Color(0xFFC7D2FE);
  static const shadow = Color(0xFF1B2B4B);

  // BINAGO: Mas matingkad na yellow/amber para sa Create Trip card
  static const amberFill = Color(0xFFFFFBEB);
  static const amberLine = Color(0xFFFBBF24);
  static const amberText = Color(0xFFD97706);
}

enum TicketNotchAxis {
  /// Half-circle cutouts on the top and bottom edges (vertical dashed divider).
  topBottom,

  /// Half-circle cutouts on the left and right edges (horizontal dashed divider).
  leftRight,
}

/// A commute-ticket style card: rounded corners, two circular cutouts,
/// a dashed divider between them and a soft shadow.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.child,
    required this.fillColor,
    required this.lineColor,
    this.notchAxis = TicketNotchAxis.topBottom,
    this.notchOffset = 56,
    this.notchRadius = 9,
    this.cornerRadius = 18,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color fillColor;
  final Color lineColor;
  final TicketNotchAxis notchAxis;

  /// Distance of the notches from the left edge (topBottom)
  /// or from the top edge (leftRight).
  final double notchOffset;
  final double notchRadius;
  final double cornerRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TicketPainter(
        fill: fillColor,
        line: lineColor,
        axis: notchAxis,
        offset: notchOffset,
        notchR: notchRadius,
        corner: cornerRadius,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _TicketPainter extends CustomPainter {
  _TicketPainter({
    required this.fill,
    required this.line,
    required this.axis,
    required this.offset,
    required this.notchR,
    required this.corner,
  });

  final Color fill;
  final Color line;
  final TicketNotchAxis axis;
  final double offset;
  final double notchR;
  final double corner;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(corner),
        ),
      );

    final cuts = Path();
    if (axis == TicketNotchAxis.topBottom) {
      cuts
        ..addOval(Rect.fromCircle(center: Offset(offset, 0), radius: notchR))
        ..addOval(
          Rect.fromCircle(center: Offset(offset, size.height), radius: notchR),
        );
    } else {
      cuts
        ..addOval(Rect.fromCircle(center: Offset(0, offset), radius: notchR))
        ..addOval(
          Rect.fromCircle(center: Offset(size.width, offset), radius: notchR),
        );
    }

    final ticket = Path.combine(PathOperation.difference, base, cuts);

    // Soft shadow
    canvas.drawPath(
      ticket.shift(const Offset(0, 4)),
      Paint()
        ..color = TicketPalette.shadow.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Fill
    canvas.drawPath(ticket, Paint()..color = fill);

    // Border
    canvas.drawPath(
      ticket,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = line.withValues(alpha: 0.7),
    );

    // Dashed divider
    final dashPaint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = line.withValues(alpha: 0.65);

    if (axis == TicketNotchAxis.topBottom) {
      _dashLine(
        canvas,
        Offset(offset, notchR + 6),
        Offset(offset, size.height - notchR - 6),
        dashPaint,
      );
    } else {
      _dashLine(
        canvas,
        Offset(notchR + 6, offset),
        Offset(size.width - notchR - 6, offset),
        dashPaint,
      );
    }
  }

  void _dashLine(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      c.drawLine(a + dir * d, a + dir * math.min(d + dash, total), p);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPainter old) =>
      old.fill != fill ||
      old.line != line ||
      old.axis != axis ||
      old.offset != offset ||
      old.notchR != notchR ||
      old.corner != corner;
}

/// Entry point to the Itinerary, intended for the Trips screen.
/// Pass the same navigation call the old bottom-nav tab used, e.g.
/// `onTap: () => context.go(AppRoutes.itinerary)`.
class ItineraryEntryTile extends StatelessWidget {
  const ItineraryEntryTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TicketCard(
        fillColor: TicketPalette.lavenderFill,
        lineColor: TicketPalette.lavenderLine,
        notchOffset: 56,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const SizedBox(
              width: 56,
              child: Center(
                child: Icon(
                  Icons.route_rounded,
                  size: 22,
                  color: AppColors.navy,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View Itinerary',
                      style: AppText.ui(
                        14,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stops, times and routes for your trip',
                      style: AppText.ui(
                        11,
                        FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.navy),
            ),
          ],
        ),
      ),
    );
  }
}