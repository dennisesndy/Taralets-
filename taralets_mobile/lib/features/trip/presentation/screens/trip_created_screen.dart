import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/ticket_card.dart';

/// Trip Created: animated success badge and the room code on a ticket.
class TripCreatedScreen extends StatelessWidget {
  const TripCreatedScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Animated success badge with confetti dots
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(scale: t, child: child),
                  ),
                  child: const SizedBox(height: 150, child: _SuccessBadge()),
                ),
                const SizedBox(height: 16),
                Text(
                  "You're all set!",
                  textAlign: TextAlign.center,
                  style: AppText.ui(28, FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your group trip has been created. Share the code so your friends can join!',
                  textAlign: TextAlign.center,
                  style: AppText.ui(
                    14,
                    FontWeight.w400,
                    color: AppColors.muted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Room code ticket
                TicketCard(
                  fillColor: TicketPalette.skyFill,
                  lineColor: TicketPalette.skyLine,
                  notchAxis: TicketNotchAxis.leftRight,
                  notchOffset: 44,
                  notchRadius: 10,
                  cornerRadius: 20,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: Center(
                          child: Text(
                            'ROOM CODE',
                            style: AppText.ui(
                              11,
                              FontWeight.w700,
                              color: TicketPalette.skyText,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: Text(
                          trip.code,
                          style: AppText.mono(
                            32,
                            FontWeight.w800,
                            color: AppColors.navy,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TaraletsButton.orange(
                  label: 'View Trip',
                  onPressed: () => context.go(AppRoutes.groupPrefs),
                ),
                const SizedBox(height: 12),
                TaraletsButton.ghost(
                  label: 'Invite More Friends',
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            'Join my Taralets trip with room code ${trip.code}',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite message copied')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    Widget dot(double size, Color c) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        // Soft rings
        Container(
          width: 140,
          height: 140,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
        ),
        // Confetti dots
        Positioned(top: 10, left: 62, child: dot(9, TicketPalette.redLine)),
        Positioned(top: 34, right: 52, child: dot(7, AppColors.gold)),
        Positioned(bottom: 18, left: 58, child: dot(8, TicketPalette.skyLine)),
        Positioned(bottom: 40, right: 56, child: dot(6, TicketPalette.redLine)),
        Positioned(top: 62, left: 44, child: dot(6, AppColors.gold)),
      ],
    );
  }
}