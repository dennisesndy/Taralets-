import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../data/manila_places.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/taralets_card.dart';
import '../../../../shared/widgets/taralets_chip.dart';
import '../../../../shared/widgets/ticket_card.dart';
import '../../../discover/data/discover_places_provider.dart';
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

    final placesAsync = ref.watch(discoverPlacesProvider);
    final allPlaces = placesAsync.valueOrNull ?? const <Place>[];

    // Use the same database-backed place feed as Discover.
    final filteredPlaces = _category == 'All'
        ? allPlaces
        : allPlaces
            .where((place) => _matchesCategory(place, _category))
            .toList();

    return ColoredBox(
      color: AppColors.bg,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -----------------------------------------------------------------
            // Header
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // AVATAR
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.profile),
                        child: Avatar(name: displayName, size: 46),
                      ),
                      Expanded(
                        child: Center(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Taralets',
                                  style: GoogleFonts.pacifico(
                                    fontSize: 30,
                                    color: AppColors.brandOrange,
                                  ),
                                ),
                                TextSpan(
                                  text: '!',
                                  style: GoogleFonts.pacifico(
                                    fontSize: 30,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                      // NOTIFICATION BELL ICON
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: TicketPalette.shadow.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.navy,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Explore Manila!',
                    style: AppText.ui(
                      28,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.discover),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.only(left: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: TicketPalette.lavenderLine.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TicketPalette.shadow.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Create / Join Trip actions
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          lineColor: TicketPalette.amberLine,
                          fillColor: TicketPalette.amberFill,
                          textColor: TicketPalette.amberText,
                          icon: AppIcons.plus(
                            color: TicketPalette.amberText,
                            size: 18,
                          ),
                          title: 'Create Trip',
                          subtitle: 'Plan with group',
                          onTap: () => context.push(AppRoutes.createTrip),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionTile(
                          lineColor: TicketPalette.skyLine,
                          fillColor: TicketPalette.skyFill,
                          textColor: TicketPalette.skyText,
                          icon: AppIcons.users(
                            color: TicketPalette.skyText,
                            size: 18,
                          ),
                          title: 'Join a Trip',
                          subtitle: 'Enter invite code',
                          onTap: () => context.push(AppRoutes.joinTrip),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Dynamic Trip Card (Ipapakita kung may existing trip)
                  if (displayTrip != null) ...[
                    _ActiveTripCard(trip: displayTrip),
                    const SizedBox(height: 24),
                  ] else ...[
                    const _EmptyTripCard(),
                    const SizedBox(height: 24),
                  ],

                  // Category browser
                  Text(
                    'Browse by Category',
                    style: AppText.ui(
                      18,
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

                  const SizedBox(height: 24),

                  // Recommended Places
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Recommended Places',
                        style: AppText.ui(
                          18,
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

                  if (placesAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.orange,
                        ),
                      ),
                    )
                  else if (placesAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Could not load places. Please try Discover again.',
                        style: AppText.ui(
                          13,
                          FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  else if (filteredPlaces.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No places found in this category yet.',
                        style: AppText.ui(
                          13,
                          FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  else
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
                        const SizedBox(height: 14),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesCategory(Place place, String selected) {
    final category = place.category.toLowerCase();
    switch (selected) {
      case 'Heritage':
        return category.contains('heritage') ||
            category.contains('historical') ||
            category.contains('church') ||
            category.contains('religious');
      case 'Food & Cafés':
        return category.contains('food') ||
            category.contains('cafe') ||
            category.contains('restaurant') ||
            category.contains('eatery') ||
            category.contains('dessert') ||
            category.contains('bakery');
      case 'Museums':
        return category.contains('museum');
      case 'Parks':
        return category.contains('park') || category.contains('nature');
      case 'Shopping':
        return category.contains('shopping') || category.contains('retail');
      default:
        return category == selected.toLowerCase();
    }
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
      child: TicketCard(
        fillColor: TicketPalette.lavenderFill,
        lineColor: TicketPalette.lavenderLine,
        notchOffset: 64,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppIcons.plus(color: AppColors.orange, size: 18),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
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
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.chevron_right, color: AppColors.orange),
            ),
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

  static const double _stubHeight = 50;

  @override
  Widget build(BuildContext context) {
    final soft = AppColors.navy.withValues(alpha: 0.65);
    final faint = AppColors.navy.withValues(alpha: 0.45);

    // Gawing dynamic ang mga kulay at text base sa status
    final isUpcoming = trip.status != TripStatus.active;
    final badgeColor = isUpcoming ? AppColors.amber : AppColors.green;
    final badgeText = isUpcoming ? 'UPCOMING TRIP' : 'ACTIVE TRIP';

    return GestureDetector(
      onTap: () => context.go(
        AppRoutes.itinerary,
        extra: {'tripId': trip.id},
      ),
      child: TicketCard(
        fillColor: TicketPalette.lavenderFill,
        lineColor: TicketPalette.lavenderLine,
        notchAxis: TicketNotchAxis.leftRight,
        notchOffset: _stubHeight,
        notchRadius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ticket stub (above the dashed divider)
            SizedBox(
              height: _stubHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
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
                            11,
                            FontWeight.w700,
                            color: badgeColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.12),
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
              ),
            ),

            // Ticket body (below the dashed divider)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    style: AppText.ui(
                      20,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AppIcons.pin(color: faint),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          trip.meetup,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(12, FontWeight.w500, color: soft),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppIcons.clock(color: faint),
                      const SizedBox(width: 5),
                      Text(
                        'Arrival ${trip.arrivalTarget}',
                        style: AppText.ui(12, FontWeight.w500, color: soft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      AvatarStack(
                        names: trip.memberNames,
                        size: 28,
                        ringColor: TicketPalette.lavenderFill,
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
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Action Tile (Create / Join ticket)
// =============================================================================

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.lineColor,
    required this.fillColor,
    required this.textColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color lineColor;
  final Color fillColor;
  final Color textColor;
  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TicketCard(
        fillColor: fillColor,
        lineColor: lineColor,
        notchOffset: 52,
        notchRadius: 8,
        cornerRadius: 16,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: lineColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: icon,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(14, FontWeight.w800, color: textColor),
                    ),
                    const SizedBox(height: 2),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        // TINANGGAL: IntrinsicHeight. IPINALIT: SizedBox na may fixed height.
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 88,
                  height: 96,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [TicketPalette.skyFill, TicketPalette.amberFill],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(p.emoji, style: const TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // IPINALIT: MainAxisAlignment.spaceBetween imbes na Spacer()
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // TOP SECTION (Name, Heart, Subtitle, Hours)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.ui(
                                  15,
                                  FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onToggleSave,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: AppIcons.heart(
                                  filled: saved,
                                  color: AppColors.primary,
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
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              AppIcons.clock(color: AppColors.muted),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  p.openingHours,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.ui(
                                    11,
                                    FontWeight.w500,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // BOTTOM SECTION (Ratings, Price, Distance, Status)
                    Row(
                      children: [
                        AppIcons.star(color: TicketPalette.amberLine),
                        const SizedBox(width: 3),
                        Text(
                          '${p.rating}',
                          style: AppText.ui(12, FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: TicketPalette.skyText.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.price,
                            style: AppText.ui(
                              11,
                              FontWeight.w700,
                              color: TicketPalette.skyText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dynamicDistanceLabel,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(
                              12,
                              FontWeight.w400,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
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
            ],
          ),
        ),
      ),
    );
  }
}
