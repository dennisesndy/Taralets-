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
import '../../../notifications/presentation/screens/notifications_screen.dart'; // IMPORT PARA SA NOTIFICATIONS

/// Home screen for the Taralets app.
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
    // Kunin ang tunay na account details mula sa user
    final user = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);

    // Dynamic fallback para sa pangalan
    final String displayName =
        user?.firstName != null && user!.firstName.isNotEmpty
        ? user.firstName
        : 'User';

    final trips = ref
        .watch(myTripsProvider)
        .maybeWhen(data: (t) => t, orElse: () => const <Trip>[]);

    // Binago ang logic dito: Ipakita ang unang trip (upcoming man o active)
    final displayTrip = trips.firstOrNull;

    // Filter recommended places based on the selected category.
    final filteredPlaces = _category == 'All'
        ? manilaPlaces
        : manilaPlaces.where((p) => p.category == _category).toList();

    return ColoredBox(
      color: AppColors.bg,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -----------------------------------------------------------------
            // Header
            // -----------------------------------------------------------------
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
                              '$displayName! 👋',
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
                      // NOTIFICATION BELL ICON
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                        ),
                      ),
                      // AVATAR
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.profile),
                        child: Avatar(name: displayName, size: 42),
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

            // -----------------------------------------------------------------
            // Body
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dynamic Trip Card (Ipapakita kung may existing trip)
                  if (displayTrip != null) ...[
                    _ActiveTripCard(trip: displayTrip),
                    const SizedBox(height: 20),
                  ] else ...[
                    const _EmptyTripCard(),
                    const SizedBox(height: 20),
                  ],

                  // Create / Join Trip actions
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
                          onTap: () => context.push(AppRoutes.createTrip),
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

                  // Explore Manila
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
                            onTap: () => setState(() {
                              _category = c;
                            }),
                          ),
                          if (c != _cats.last) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Recommended Places
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

                  // Use the filtered list so category chips actually work.
                  for (final p in filteredPlaces.take(4)) ...[
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
                    if (p.id != filteredPlaces.take(4).last.id)
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

// =============================================================================
// Empty Trip Card
// =============================================================================

class _EmptyTripCard extends StatelessWidget {
  const _EmptyTripCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.createTrip),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.orangeSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
              ),
              child: AppIcons.plus(color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No active trips',
                    style: AppText.ui(
                      15,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Create a trip now and plan your gala!',
                    style: AppText.ui(
                      12,
                      FontWeight.w400,
                      color: AppColors.navy.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.orange),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Active Trip Card
// =============================================================================

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final soft = Colors.white.withValues(alpha: 0.6);
    final faint = Colors.white.withValues(alpha: 0.5);

    // Gawing dynamic ang mga kulay at text base sa status
    final isUpcoming = trip.status != TripStatus.active;
    final badgeColor = isUpcoming ? AppColors.amber : AppColors.green;
    final badgeText = isUpcoming ? 'UPCOMING TRIP' : 'ACTIVE TRIP';

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
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: AppText.ui(
                        10,
                        FontWeight.w700,
                        color: badgeColor,
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
                    isUpcoming ? 'Soon' : 'Today',
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
                    '${trip.onWayCount} of ${trip.memberCount} joined',
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

// =============================================================================
// Action Tile
// =============================================================================

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

// =============================================================================
// Place Row
// =============================================================================

class _PlaceRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final p = place;

    // Get the user's live location and calculate the distance
    // to the recommended place.
    final locationAsync = ref.watch(userLocationProvider);

    final dynamicDistanceLabel = locationAsync.maybeWhen(
      data: (pos) {
        final dist = calculateDistanceKm(pos, p.lat, p.lng);

        return dist != null ? '${dist.toStringAsFixed(1)} km' : p.distanceLabel;
      },
      orElse: () => p.distanceLabel,
    );

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

                    // Opening hours from the revised version.
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '🕒 ${p.openingHours}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          11,
                          FontWeight.w500,
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
                          dynamicDistanceLabel,
                          style: AppText.ui(
                            12,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                        const Spacer(),
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