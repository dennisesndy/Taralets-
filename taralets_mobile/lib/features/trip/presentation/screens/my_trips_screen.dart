import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/taralets_button.dart';

class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(myTripsProvider);

    return ColoredBox(
      color: AppColors.bg,
      child: trips.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (e, s) => Center(
          child: Text(
            "Couldn't load your trips.",
            style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
          ),
        ),
        data: (items) {
          Iterable<Trip> of(TripStatus s) => items.where((t) => t.status == s);
          final sections = [
            ('Active', of(TripStatus.active).toList()),
            ('Upcoming', of(TripStatus.upcoming).toList()),
            ('Completed', of(TripStatus.done).toList()),
          ].where((s) => s.$2.isNotEmpty);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'My Trips',
                style: AppText.ui(20, FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 16),
              for (final s in sections) ...[
                Text(
                  s.$1.toUpperCase(),
                  style: AppText.ui(
                    13,
                    FontWeight.w700,
                    color: AppColors.muted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                for (final t in s.$2) ...[
                  _TripCard(trip: t),
                  if (t != s.$2.last) const SizedBox(height: 8),
                ],
                const SizedBox(height: 20),
              ],
              TaraletsButton.orange(
                label: '+ Create New Trip',
                onPressed: () => context.push(AppRoutes.createTrip),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final (accent, pillBg, pillFg, pillLabel) = switch (trip.status) {
      TripStatus.active => (
        AppColors.orange,
        AppColors.orangeSoft,
        AppColors.orange,
        'Active',
      ),
      TripStatus.upcoming => (
        AppColors.navy,
        AppColors.blueSoft,
        AppColors.navy,
        'Upcoming',
      ),
      TripStatus.done => (
        AppColors.green,
        AppColors.greenSoft,
        AppColors.green,
        '✓ Done',
      ),
    };
    final meta = AppText.ui(12, FontWeight.w400, color: AppColors.muted);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent), // borderLeft: 4px solid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            trip.title,
                            style: AppText.ui(14, FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            pillLabel,
                            style: AppText.ui(
                              10,
                              FontWeight.w700,
                              color: pillFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcons.clock(),
                            const SizedBox(width: 4),
                            Text(trip.dateLabel, style: meta),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcons.users(size: 12),
                            const SizedBox(width: 4),
                            Text('${trip.memberCount} members', style: meta),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcons.pin(color: AppColors.muted, size: 16),
                            const SizedBox(width: 4),
                            Text(trip.meetup, style: meta),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
