import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/taralets_button.dart';

/// Figma `TripCreated`: white screen, 80sp party popper, room code card.
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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 80),
                ),
                const SizedBox(height: 16),
                Text(
                  "You're all set!",
                  textAlign: TextAlign.center,
                  style: AppText.ui(26, FontWeight.w900, color: AppColors.navy),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'ROOM CODE',
                        style: AppText.ui(
                          11,
                          FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trip.code,
                        style: AppText.mono(
                          32,
                          FontWeight.w900,
                          color: AppColors.navy,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TaraletsButton.orange(
                  label: 'View Trip',
                  onPressed: () => context.go(AppRoutes.groupPrefs),
                ),
                const SizedBox(height: 16),
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
