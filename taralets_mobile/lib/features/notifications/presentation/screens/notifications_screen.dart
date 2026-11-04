import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../features/profile/data/friends_repository.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/notifications_repository.dart';
import '../../../../shared/widgets/back_button_tile.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshNotifications(),
    );
  }

  void _refreshNotifications() {
    if (mounted && !ref.read(notificationsProvider).isLoading) {
      ref.invalidate(notificationsProvider);
      ref.invalidate(myTripsProvider);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _respond(
    BuildContext context,
    AppNotification item,
    bool accept,
  ) async {
    try {
      final repository = ref.read(notificationsRepoProvider);
      if (item.friendRequestId != null) {
        if (accept) {
          await repository.acceptFriendRequest(item.friendRequestId!);
        } else {
          await repository.declineFriendRequest(item.friendRequestId!);
        }
        if (accept) ref.invalidate(friendsProvider);
      } else if (item.tripJoinRequestId != null && item.tripId != null) {
        await repository.resolveTripJoinRequest(
          tripId: item.tripId!,
          requestId: item.tripJoinRequestId!,
          approve: accept,
        );
      } else {
        return;
      }
      ref.invalidate(notificationsProvider);
      if (item.tripId != null) ref.invalidate(myTripsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item.friendRequestId != null
                  ? (accept
                        ? 'Friend request accepted.'
                        : 'Friend request declined.')
                  : (accept
                        ? 'Trip join request approved.'
                        : 'Trip join request declined.'),
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref
                  .read(notificationsRepoProvider)
                  .errorMessage(error, 'Could not update friend request.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openApprovedTrip(
    BuildContext context,
    AppNotification item,
  ) async {
    if (item.tripId == null) return;
    try {
      ref.invalidate(myTripsProvider);
      if (!context.mounted) return;
      context.go(AppRoutes.trips);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the trip yet.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    style: AppText.ui(
                      18,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notificationsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.orange),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load notifications.',
                        style: AppText.ui(
                          14,
                          FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(notificationsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_off_outlined,
                            size: 48,
                            color: AppColors.placeholder,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "You're all caught up!",
                            style: AppText.ui(
                              16,
                              FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.orange,
                    onRefresh: () async =>
                        ref.invalidate(notificationsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                              Text(
                                item.title,
                                style: AppText.ui(
                                  14,
                                  FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.message,
                                style: AppText.ui(
                                  13,
                                  FontWeight.w400,
                                  color: AppColors.text,
                                ),
                              ),
                              if (item.actionable &&
                                  (item.type == 'friend_request' ||
                                      item.type == 'trip_join_request')) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _respond(context, item, false),
                                        child: const Text('Decline'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () =>
                                            _respond(context, item, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.orange,
                                        ),
                                        child: const Text('Accept'),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if ((item.type == 'friend_request' ||
                                      item.type == 'trip_join_request' ||
                                      item.type ==
                                          'trip_join_request_resolved') &&
                                  item.requestStatus != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  item.requestStatus == 'accepted'
                                      ? 'Accepted'
                                      : 'Declined',
                                  style: AppText.ui(
                                    12,
                                    FontWeight.w700,
                                    color: item.requestStatus == 'accepted'
                                        ? AppColors.green
                                        : AppColors.muted,
                                  ),
                                ),
                                if (item.type == 'trip_join_request_resolved' &&
                                    item.requestStatus == 'accepted' &&
                                    item.tripId != null) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () =>
                                          _openApprovedTrip(context, item),
                                      icon: const Icon(Icons.luggage_rounded),
                                      label: const Text('View in My Trips'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                      },
                    ),
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
