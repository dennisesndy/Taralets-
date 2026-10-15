import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/dashed_border_box.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/ticket_card.dart'; // IDINAGDAG: TicketCard import
import '../../data/models/member.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key, required this.trip});
  final Trip trip;

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _Plan {
  const _Plan(this.from, this.travelMin, this.traffic, this.status);
  final String from;
  final int travelMin;
  final String traffic;
  final PresenceStatus status;
}

const Map<String, _Plan> _plans = {
  'dennise': _Plan('Sampaloc', 28, 'Heavy', PresenceStatus.onWay),
  'ana': _Plan('Tondo', 22, 'Moderate', PresenceStatus.onWay),
  'paola': _Plan('Sta. Cruz', 15, 'Moderate', PresenceStatus.onWay),
  'jewelle': _Plan('Ermita', 12, 'Moderate', PresenceStatus.notLeft),
};

const _Plan _fallbackPlan = _Plan(
  'Paco',
  20,
  'Moderate',
  PresenceStatus.notLeft,
);

const int _bufferMin = 15;

String _fmtDur(int m) =>
    m >= 60 ? '${m ~/ 60} hr${m % 60 != 0 ? ' ${m % 60} min' : ''}' : '$m min';

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  late final Trip _trip = widget.trip;

  bool _paused = false;
  bool _busy = false;

  _Plan _planFor(Member m) => _plans[m.username] ?? _fallbackPlan;

  int get _onWay => _trip.members
      .where((m) => _planFor(m).status == PresenceStatus.onWay)
      .length;

  BoxDecoration get _cardDeco => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Future<void> _complete() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const _CompleteDialog(),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(tripRepositoryProvider).completeTrip(_trip.id);
      ref.invalidate(myTripsProvider);
      if (!mounted) return;
      context.go(AppRoutes.trips);
      messenger.showSnackBar(const SnackBar(content: Text('Trip completed')));
    } on TripException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    final isLeader = _trip.isLeader(me?.id);

    final target = parseTimeOfDay(_trip.arrivalTarget);
    final targetMin = target.hour * 60 + target.minute;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _liveBanner(),
                    const SizedBox(height: 16),
                    _presenceStrip(),
                    const SizedBox(height: 24),
                    Text(
                      'Departure Schedule',
                      style: AppText.ui(
                        16,
                        FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final m in _trip.members) ...[
                      _scheduleCard(m, targetMin),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    _destinationCard(), // BOARDING PASS THEME APPLIED
                    const SizedBox(height: 16),
                    _liveUpdatesPlaceholder(),
                    const SizedBox(height: 16),
                    _recsPlaceholder(),
                    if (isLeader) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Host Options',
                        style: AppText.ui(13, FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TaraletsButton.ghost(
                              label: _paused ? 'Resume Trip' : 'Pause Trip',
                              onPressed: () =>
                                  setState(() => _paused = !_paused),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TaraletsButton.navy(
                              label: 'Complete Trip',
                              isLoading: _busy,
                              onPressed: _complete,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BackButtonTile(onTap: () => context.go(AppRoutes.home)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(
                        18,
                        FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Today • Target arrival ${_trip.arrivalTarget}',
                      style: AppText.ui(
                        13,
                        FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                AppIcons.pin(color: AppColors.primary), // Changed to Rose
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MEETUP LOCATION',
                        style: AppText.ui(
                          10,
                          FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _trip.meetupFull,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          14,
                          FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ON THE WAY',
                      style: AppText.ui(
                        10,
                        FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_onWay/${_trip.memberCount}',
                      style: AppText.ui(
                        15,
                        FontWeight.w800,
                        color: AppColors.primaryLight, // Changed to light Rose
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveBanner() {
    final bg = _paused ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4);
    final border = _paused ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0);
    final title = _paused ? const Color(0xFF92400E) : const Color(0xFF166534);
    final body = _paused ? const Color(0xFFA16207) : const Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _paused ? AppColors.amber : AppColors.green,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _paused ? 'Trip is Paused' : 'Trip is Live',
                  style: AppText.ui(13, FontWeight.w800, color: title),
                ),
                const SizedBox(height: 2),
                Text(
                  _paused
                      ? 'The host paused the trip. Hang tight.'
                      : 'Everyone is heading to the meetup location.',
                  style: AppText.ui(
                    12,
                    FontWeight.w500,
                    color: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presenceStrip() {
    Color dot(PresenceStatus s) => switch (s) {
      PresenceStatus.onWay || PresenceStatus.arrived => AppColors.green,
      PresenceStatus.notLeft => AppColors.amber,
      PresenceStatus.delayed => AppColors.red,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('On this trip', style: AppText.ui(14, FontWeight.w800, color: AppColors.navy)),
              Text(
                '${_trip.memberCount} members',
                style: AppText.ui(12, FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in _trip.members) ...[
                  Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Avatar(name: m.name, size: 48),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: dot(_planFor(m).status),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.isLeader ? 'Host' : m.name,
                        style: AppText.ui(
                          11,
                          m.isLeader ? FontWeight.w800 : FontWeight.w600,
                          color: m.isLeader
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  if (m != _trip.members.last) const SizedBox(width: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(Member m, int targetMin) {
    final plan = _planFor(m);
    final heavy = plan.traffic.contains('Heavy');

    Widget box(String label, Widget value, {Color? bg}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg ?? AppColors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppText.ui(9, FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
            ),
            const SizedBox(height: 2),
            value,
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco,
      child: Column(
        children: [
          Row(
            children: [
              Avatar(name: m.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m.name, style: AppText.ui(15, FontWeight.w800, color: AppColors.navy)),
                        StatusBadge(status: plan.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Origin: ${plan.from}',
                      style: AppText.ui(
                        12,
                        FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              box(
                'Leave by',
                Text(
                  formatMinutes(targetMin - plan.travelMin - _bufferMin),
                  style: AppText.mono(
                    14,
                    FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              box(
                'Travel time',
                Text(
                  _fmtDur(plan.travelMin),
                  style: AppText.ui(13, FontWeight.w700, color: AppColors.navy),
                ),
              ),
              const SizedBox(width: 8),
              box(
                'Traffic',
                Text(
                  plan.traffic.split(' ').first,
                  style: AppText.ui(
                    12,
                    FontWeight.w800,
                    color: heavy ? const Color(0xFF92400E) : AppColors.text,
                  ),
                ),
                bg: heavy ? const Color(0xFFFEF3C7) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // BINAGO: Ang Destination Card ay ginawang Transit Ticket format
  Widget _destinationCard() {
    return TicketCard(
      fillColor: TicketPalette.skyFill,
      lineColor: TicketPalette.skyLine,
      notchAxis: TicketNotchAxis.leftRight,
      notchOffset: 95,
      cornerRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Ticket Part
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.flag_circle_rounded, color: TicketPalette.skyText, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DESTINATION',
                        style: AppText.ui(10, FontWeight.w800, color: TicketPalette.skyText, letterSpacing: 1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _trip.meetupFull,
                        style: AppText.ui(16, FontWeight.w800, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom Ticket Part
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DATE',
                        style: AppText.ui(10, FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _trip.longDate,
                        style: AppText.ui(14, FontWeight.w700, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SCHEDULE',
                        style: AppText.ui(10, FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_trip.arrivalTarget} – ${_trip.wrapUp}',
                        style: AppText.ui(14, FontWeight.w700, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // BINAGO: Mas clean na status indicator para sa Live Updates
  Widget _liveUpdatesPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.sensors_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Group Updates', style: AppText.ui(15, FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 4),
                Text('Check-ins and delays will appear here once tracking is active.', style: AppText.ui(12, FontWeight.w500, color: AppColors.primary.withValues(alpha: 0.8), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // BINAGO: Vibrant banner papuntang recommendations
  Widget _recsPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4EB), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.orange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Itinerary Ideas', style: AppText.ui(15, FontWeight.w800, color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Text('Places picked based on your group prefs.', style: AppText.ui(12, FontWeight.w500, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TaraletsButton.orange(
            small: true,
            label: 'View Recommendations',
            onPressed: () => context.push(AppRoutes.recommendations),
          ),
        ],
      ),
    );
  }
}

class _CompleteDialog extends StatelessWidget {
  const _CompleteDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Complete this trip?',
              style: AppText.ui(18, FontWeight.w900, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'This ends the trip for everyone and moves it to Completed.',
              style: AppText.ui(
                13,
                FontWeight.w500,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            TaraletsButton.navy(
              label: 'Complete Trip',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 12),
            TaraletsButton.ghost(
              label: 'Not yet',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}