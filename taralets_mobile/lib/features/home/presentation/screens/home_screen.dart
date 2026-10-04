import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/manila_places.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/dashed_border_box.dart';
import '../../../../shared/widgets/taralets_card.dart';
import '../../../../shared/widgets/taralets_chip.dart';
import '../../../discover/presentation/screens/place_detail_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _cats = [
    'All',
    'Heritage',
    'Food & Cafés',
    'Museums',
    'Parks',
    'Shopping',
  ];

  String _category = 'All';
  final Set<int> _saved = {};

  @override
  Widget build(BuildContext context) {
    final user = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);

    final trips = ref
        .watch(myTripsProvider)
        .maybeWhen(data: (t) => t, orElse: () => const <Trip>[]);

    final active = trips
        .where((t) => t.status == TripStatus.active)
        .firstOrNull;

    return ColoredBox(
      color: AppColors.bg,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Header --------------------------------------------------
            Container(
              color: AppColors.navy,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greetingFor(DateTime.now()),
                              style: AppText.ui(
                                13,
                                FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              '${user?.firstName ?? 'Dennise'}! 👋',
                              style: AppText.ui(
                                20,
                                FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ready for your next gala?',
                              style: AppText.ui(
                                12,
                                FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.profile),
                        child: Avatar(
                          name: user?.firstName ?? 'Dennise',
                          size: 42,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.discover),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.only(left: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          AppIcons.search(),
                          const SizedBox(width: 12),
                          Text(
                            'Search places in Manila...',
                            style: AppText.ui(
                              14,
                              FontWeight.w400,
                              color: AppColors.placeholder,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- Body ----------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (active != null) ...[
                    _ActiveTripCard(trip: active),
                    const SizedBox(height: 20),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          color: AppColors.orange,
                          tileColor: AppColors.orangeSoft,
                          icon: AppIcons.plus(
                            color: AppColors.orange,
                            size: 18,
                          ),
                          title: 'Create Trip',
                          subtitle: 'Plan with group',
                          onTap: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Create Trip is coming next.'),
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          color: AppColors.navy,
                          tileColor: AppColors.blueSoft,
                          icon: AppIcons.users(color: AppColors.navy, size: 18),
                          title: 'Join a Trip',
                          subtitle: 'Enter invite code',
                          onTap: () => context.push(AppRoutes.joinTrip),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Explore Manila',
                    style: AppText.ui(
                      16,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        for (final c in _cats) ...[
                          TaraletsChip(
                            label: c,
                            selected: _category == c,
                            onTap: () => setState(() => _category = c),
                          ),
                          if (c != _cats.last) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recommended Places',
                        style: AppText.ui(
                          16,
                          FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.discover),
                        child: Text(
                          'See all',
                          style: AppText.ui(
                            13,
                            FontWeight.w600,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  for (final p in manilaPlaces.take(4)) ...[
                    _PlaceRow(
                      place: p,
                      saved: _saved.contains(p.id),
                      onToggleSave: () => setState(() {
                        if (!_saved.add(p.id)) {
                          _saved.remove(p.id);
                        }
                      }),
                      onTap: () => showPlaceDetail(context, p),
                    ),
                    if (p.id != manilaPlaces.take(4).last.id)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final soft = Colors.white.withValues(alpha: 0.6);
    final faint = Colors.white.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () => context.go(AppRoutes.itinerary),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ACTIVE TRIP',
                      style: AppText.ui(
                        10,
                        FontWeight.w700,
                        color: AppColors.green,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Today',
                    style: AppText.ui(
                      11,
                      FontWeight.w700,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              trip.title,
              style: AppText.ui(16, FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                AppIcons.pin(color: faint),
                const SizedBox(width: 5),
                Text(
                  trip.meetup,
                  style: AppText.ui(12, FontWeight.w400, color: soft),
                ),
                const SizedBox(width: 12),
                AppIcons.clock(color: faint),
                const SizedBox(width: 5),
                Text(
                  'Arrival ${trip.arrivalTarget}',
                  style: AppText.ui(12, FontWeight.w400, color: soft),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AvatarStack(
                  names: trip.memberNames,
                  size: 26,
                  ringColor: AppColors.navy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${trip.onWayCount} of ${trip.memberCount} on the way',
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(12, FontWeight.w400, color: soft),
                  ),
                ),
                Text(
                  'View →',
                  style: AppText.ui(
                    12,
                    FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.color,
    required this.tileColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final Color tileColor;
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DashedBorderBox(
        color: color,
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(
                      13,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(
                      11,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.saved,
    required this.onToggleSave,
    required this.onTap,
  });

  final Place place;
  final bool saved;
  final VoidCallback onToggleSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = place;

    return TaraletsCard(
      clip: true,
      blur: 8,
      shadowAlpha: 0.06,
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 90,
              height: 90,
              color: AppColors.bg,
              alignment: Alignment.center,
              child: Text(p.emoji, style: const TextStyle(fontSize: 36)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(14, FontWeight.w700),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onToggleSave,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: AppIcons.heart(
                              filled: saved,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        p.sub,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          12,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        AppIcons.star(),
                        const SizedBox(width: 3),
                        Text(
                          '${p.rating}',
                          style: AppText.ui(12, FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.price,
                          style: AppText.ui(
                            12,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.distanceLabel,
                          style: AppText.ui(
                            12,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: p.isOpen
                                ? AppColors.greenSoft
                                : AppColors.redSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.isOpen ? 'Open' : 'Closed',
                            style: AppText.ui(
                              11,
                              FontWeight.w600,
                              color: p.isOpen ? AppColors.green : AppColors.red,
                            ),
                          ),
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
