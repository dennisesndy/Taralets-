import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:taralets_mobile/core/constants/app_colors.dart';
import 'package:taralets_mobile/core/constants/app_text.dart';
import 'package:taralets_mobile/shared/widgets/back_button_tile.dart';
// TAMA NA ANG IMPORT DITO BASE SA IYONG SCREENSHOT:
import 'package:taralets_mobile/repositories/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  BackButtonTile(onTap: () => context.pop()),
                  const SizedBox(width: 12),
                  Text(
                    'Notifications',
                    style: AppText.ui(18, FontWeight.w800, color: AppColors.navy),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notificationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.orange)),
                error: (e, s) => Center(
                  child: Text('Could not load notifications', style: AppText.ui(14, FontWeight.w500, color: AppColors.muted)),
                ),
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.placeholder),
                          const SizedBox(height: 16),
                          Text(
                            "You're all caught up!",
                            style: AppText.ui(16, FontWeight.w600, color: AppColors.muted),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: AppText.ui(14, FontWeight.w700, color: AppColors.navy)),
                            const SizedBox(height: 4),
                            Text(item.message, style: AppText.ui(13, FontWeight.w400, color: AppColors.text)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}