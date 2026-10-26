import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_chip.dart';
import '../../../../shared/widgets/taralets_dialogs.dart';
import '../../../../shared/widgets/ticket_card.dart';

String _tripDateLabel(Trip trip) {
  final date = trip.date?.toLocal();
  if (date == null) return trip.dateLabel;

  final today = DateUtils.dateOnly(DateTime.now());
  final tripDay = DateUtils.dateOnly(date);
  final daysUntilTrip = tripDay.difference(today).inDays;
  if (daysUntilTrip == 0) return 'Today';
  if (daysUntilTrip == 1) return 'Tomorrow';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class MyTripsScreen extends ConsumerStatefulWidget {
  const MyTripsScreen({super.key});

  @override
  ConsumerState<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends ConsumerState<MyTripsScreen> {
  static const _filters = ['All', 'Active', 'Upcoming', 'Completed'];
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(myTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg, // Clean white bg
      body: SafeArea(
        bottom: false, // Hayaan nating umabot hanggang ibaba ang kulay ng container
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER (Navy)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Trips',
                        style: AppText.ui(28, FontWeight.w900, color: AppColors.navy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your travel itineraries',
                        style: AppText.ui(13, FontWeight.w500, color: AppColors.muted),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: AppIcons.compass(color: AppColors.navy, size: 20),
                  ),
                ],
              ),
            ),

            // 2. FILTER CHIPS (Square-ish, Rose / Primary color when active)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (final f in _filters) ...[
                    _buildFilterChip(f),
                    if (f != _filters.last) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. VIBRANT NAVY CONTAINER FOR TICKETS
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.navy, 
                      Color(0xFF2A3F6D), // Lighter, elegant navy/slate blend
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: trips.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (e, s) => _buildErrorState(),
                    data: (items) => _buildList(items),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String f) {
    final selected = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ] : [],
        ),
        child: Text(
          f,
          style: AppText.ui(
            13,
            selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Trip> items) {
    Iterable<Trip> of(TripStatus s) => items.where((t) => t.status == s);
    final sections = [
      ('Active', of(TripStatus.active).toList()),
      ('Upcoming', of(TripStatus.lobby).toList()),
      ('Completed', of(TripStatus.completed).toList()),
    ].where((s) => s.$2.isNotEmpty).toList();

    final visible = _filter == 'All'
        ? sections
        : sections.where((s) => s.$1 == _filter).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: () async => ref.invalidate(myTripsProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 100),
        children: [
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No $_filter trips found.',
                  style: AppText.ui(14, FontWeight.w500, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ),
          for (final s in visible) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    s.$1.toUpperCase(),
                    style: AppText.ui(12, FontWeight.w800, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1.2),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft.withValues(alpha: 0.2), // Rose tint on navy
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${s.$2.length}',
                      style: AppText.ui(11, FontWeight.w800, color: AppColors.primarySoft),
                    ),
                  ),
                ],
              ),
            ),
            for (final t in s.$2) ...[
              _TripCard(trip: t),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: TicketCard(
          fillColor: TicketPalette.redFill,
          lineColor: TicketPalette.redLine,
          notchOffset: 56,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
          notchAxis: TicketNotchAxis.leftRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 56,
                child: Center(
                  child: Icon(Icons.wifi_off_rounded, color: TicketPalette.redText),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Couldn't load your trips.",
                style: AppText.ui(14, FontWeight.w700, color: AppColors.navy),
              ),
              const SizedBox(height: 6),
              Text(
                "Please check your connection and try again.",
                textAlign: TextAlign.center,
                style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TaraletsButton.ghost(
                label: 'Retry',
                onPressed: () => ref.invalidate(myTripsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip});
  final Trip trip;

  static const double _stubHeight = 48;

  /// Lobby trips open the Group Lobby, active trips open the Active Trip.
  void _open(BuildContext context) {
    switch (trip.status) {
      case TripStatus.lobby:
        context.push(AppRoutes.tripLobby, extra: trip);
      case TripStatus.active:
        context.push(AppRoutes.activeTrip, extra: trip);
      case TripStatus.completed:
      case TripStatus.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (fill, line, accent, pillBg, pillLabel) = switch (trip.status) {
      TripStatus.active => (
        TicketPalette.skyFill,
        TicketPalette.skyLine,
        AppColors.primary,
        AppColors.primarySoft,
        'Active',
      ),
      TripStatus.lobby => (
        TicketPalette.lavenderFill,
        TicketPalette.lavenderLine,
        AppColors.navy,
        AppColors.blueSoft,
        'Upcoming',
      ),
      TripStatus.completed => (
        const Color(0xFFF5FBF8),
        const Color(0xFFBFE6D3),
        AppColors.green,
        AppColors.greenSoft,
        'Done',
      ),
      TripStatus.cancelled => (
        TicketPalette.redFill,
        TicketPalette.redLine,
        AppColors.red,
        AppColors.redSoft,
        'Cancelled',
      ),
    };

    final label = AppText.ui(
      10,
      FontWeight.w700,
      color: AppColors.muted,
      letterSpacing: 1,
    );
    final value = AppText.ui(13, FontWeight.w700, color: AppColors.navy);
    final meta = AppText.ui(12, FontWeight.w400, color: AppColors.muted);

    final actionLabel = switch (trip.status) {
      TripStatus.lobby => 'Open lobby →',
      TripStatus.active => 'View →',
      _ => null,
    };

    final cardUI = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: TicketCard(
        fillColor: fill,
        lineColor: line,
        notchAxis: TicketNotchAxis.leftRight,
        notchOffset: _stubHeight,
        notchRadius: 10,
        cornerRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stub: status + date
            SizedBox(
              height: _stubHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (trip.status == TripStatus.completed) ...[
                            Icon(Icons.check_rounded, size: 12, color: accent),
                            const SizedBox(width: 3),
                          ] else ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            pillLabel,
                            style: AppText.ui(
                              11,
                              FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    AppIcons.clock(),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _tripDateLabel(trip),
                        overflow: TextOverflow.ellipsis,
                        style: meta,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Body: title + route row + footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.title,
                    style: AppText.ui(
                      18,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MEET UP', style: label),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                AppIcons.pin(color: AppColors.muted, size: 14),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    trip.meetup,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: value,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              _dot(accent),
                              const Expanded(child: _DashedConnector()),
                              AppIcons.users(color: accent, size: 14),
                              const Expanded(child: _DashedConnector()),
                              _dot(accent.withValues(alpha: 0.35)),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('ARRIVAL', style: label),
                            const SizedBox(height: 3),
                            Text(
                              trip.arrivalTarget,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: value,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      AvatarStack(
                        names: trip.memberNames,
                        size: 26,
                        ringColor: fill,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            AppIcons.users(size: 12),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${trip.memberCount} ${trip.memberCount == 1 ? 'member' : 'members'}',
                                overflow: TextOverflow.ellipsis,
                                style: meta,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (actionLabel != null)
                        Text(
                          actionLabel,
                          style: AppText.ui(
                            12,
                            FontWeight.w700,
                            color: AppColors.primary,
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

    final me = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    final isLeader = trip.isLeader(me?.id);

    if (trip.status == TripStatus.lobby) {
      final actionText = isLeader ? 'Cancel Trip' : 'Leave Trip';
      final dialogContent = isLeader
          ? 'Are you sure you want to cancel this trip? All members will be notified.'
          : 'Are you sure you want to leave this trip?';
      final confirmText = isLeader ? 'Yes, Cancel' : 'Yes, Leave';

      return Dismissible(
        key: Key(trip.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.redSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, color: AppColors.red),
              const SizedBox(height: 2),
              Text(
                isLeader ? 'Cancel' : 'Leave',
                style: AppText.ui(11, FontWeight.w700, color: AppColors.red),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          return await showTaraletsConfirm(
            context,
            title: actionText,
            message: dialogContent,
            confirmLabel: confirmText,
            icon: isLeader
                ? Icons.event_busy_rounded
                : Icons.logout_rounded,
          );
        },
        onDismissed: (direction) async {
          try {
            if (isLeader) {
              await ref.read(tripRepositoryProvider).cancelTrip(trip.id);
            } else {
              await ref.read(tripRepositoryProvider).leaveTrip(trip.id);
            }
            ref.invalidate(myTripsProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isLeader
                        ? 'Trip cancelled successfully.'
                        : 'You have left the trip.',
                  ),
                ),
              );
            }
          } catch (e) {
            // Error caught, provider invalidation will reset the UI
            ref.invalidate(myTripsProvider);
          }
        },
        child: cardUI,
      );
    }

    return cardUI;
  }

  Widget _dot(Color c) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

/// Small dashed line that fills the space it is given.
class _DashedConnector extends StatelessWidget {
  const _DashedConnector();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final n = (box.maxWidth / 6).floor();
        if (n <= 0) return const SizedBox.shrink();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            n,
            (_) => Container(
              width: 3,
              height: 1.5,
              color: AppColors.muted.withValues(alpha: 0.35),
            ),
          ),
        );
      },
    );
  }
}
