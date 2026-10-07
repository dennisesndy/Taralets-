import 'package:flutter/material.dart';

import '../../core/constants/app_text.dart';

/// Member travel status on the Active Trip screen (Figma `StatusBadge`).
enum PresenceStatus { notLeft, onWay, delayed, arrived }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final PresenceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      PresenceStatus.notLeft => (
        'Not Left',
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
      ),
      PresenceStatus.onWay => (
        'On the Way',
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
      ),
      PresenceStatus.delayed => (
        'Delayed',
        const Color(0xFFFEE2E2),
        const Color(0xFF991B1B),
      ),
      PresenceStatus.arrived => (
        'Arrived ✓',
        const Color(0xFFD1FAE5),
        const Color(0xFF065F46),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: AppText.ui(11, FontWeight.w700, color: fg)),
    );
  }
}
