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
import '../../data/models/member.dart';

/// Active Trip (after the leader presses Start Trip). Built from the Figma
/// "Active Trip" header + departure schedule, plus the live banner, presence
/// strip, destination summary, placeholders and host options.
class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

/// Mock travel plan per member (Manila districts only).
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

/// Figma `fmtDur`.
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
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 6,
        offset: const Offset(0, 1),
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
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _liveBanner(),
                    const SizedBox(height: 12),
                    _presenceStrip(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Departure Schedule',
                        style: AppText.ui(
                          15,
                          FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    for (final m in _trip.members) ...[
                      _scheduleCard(m, targetMin),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                    _destinationCard(),
                    const SizedBox(height: 14),
                    _recsPlaceholder(),
                    const SizedBox(height: 14),
                    _liveUpdatesPlaceholder(),
                    if (isLeader) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Host Options',
                        style: AppText.ui(13, FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
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

  // Header: same as Figma ActiveTrip.
  Widget _header() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BackButtonTile(onTap: () => context.go(AppRoutes.home)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(
                        17,
                        FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Today • Target arrival ${_trip.arrivalTarget}',
                      style: AppText.ui(
                        12,
                        FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AppIcons.pin(color: AppColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meetup Location',
                        style: AppText.ui(
                          12,
                          FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 1),
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
                      'Group',
                      style: AppText.ui(
                        11,
                        FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$_onWay/${_trip.memberCount} on the way',
                      style: AppText.ui(
                        14,
                        FontWeight.w700,
                        color: AppColors.gold,
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

  /// Live status banner (green when ongoing, amber when paused).
  Widget _liveBanner() {
    final bg = _paused ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4);
    final border = _paused ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0);
    final title = _paused ? const Color(0xFF92400E) : const Color(0xFF166534);
    final body = _paused ? const Color(0xFFA16207) : const Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _paused ? AppColors.amber : AppColors.green,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _paused ? 'Trip is Paused' : 'Trip is Ongoing',
                  style: AppText.ui(12, FontWeight.w800, color: title),
                ),
                const SizedBox(height: 2),
                Text(
                  _paused
                      ? 'The host paused the trip. Hang tight.'
                      : 'The trip is live. Everyone is heading to the meetup.',
                  style: AppText.ui(
                    11,
                    FontWeight.w400,
                    color: body,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal avatar row of everyone on the trip.
  Widget _presenceStrip() {
    Color dot(PresenceStatus s) => switch (s) {
      PresenceStatus.onWay || PresenceStatus.arrived => AppColors.green,
      PresenceStatus.notLeft => AppColors.amber,
      PresenceStatus.delayed => AppColors.red,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('On this trip', style: AppText.ui(13, FontWeight.w700)),
              Text(
                '${_trip.memberCount} members',
                style: AppText.ui(12, FontWeight.w700, color: AppColors.orange),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                          Avatar(name: m.name, size: 44),
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: dot(_planFor(m).status),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.isLeader ? 'Host' : m.name,
                        style: AppText.ui(
                          10,
                          m.isLeader ? FontWeight.w700 : FontWeight.w600,
                          color: m.isLeader
                              ? AppColors.orange
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  if (m != _trip.members.last) const SizedBox(width: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Figma departure-schedule card.
  Widget _scheduleCard(Member m, int targetMin) {
    final plan = _planFor(m);
    final heavy = plan.traffic.contains('Heavy');

    Widget box(String label, Widget value, {Color? bg}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg ?? AppColors.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.ui(10, FontWeight.w400, color: AppColors.muted),
            ),
            const SizedBox(height: 1),
            value,
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(
        children: [
          Row(
            children: [
              Avatar(name: m.name, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m.name, style: AppText.ui(14, FontWeight.w700)),
                        StatusBadge(status: plan.status),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'From ${plan.from}',
                      style: AppText.ui(
                        12,
                        FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              box(
                'Leave by',
                Text(
                  formatMinutes(targetMin - plan.travelMin - _bufferMin),
                  style: AppText.mono(
                    13,
                    FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              box(
                'Travel time',
                Text(
                  _fmtDur(plan.travelMin),
                  style: AppText.ui(12, FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              box(
                'Traffic',
                Text(
                  plan.traffic.split(' ').first,
                  style: AppText.ui(
                    11,
                    FontWeight.w700,
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

  Widget _destinationCard() {
    final rows = [
      ('📍', 'Destination', _trip.meetupFull),
      ('🗓', 'Date', _trip.longDate),
      ('⏰', 'Schedule', '${_trip.arrivalTarget} – ${_trip.wrapUp}'),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows) ...[
            Row(
              children: [
                Text(r.$1, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.$2,
                        style: AppText.ui(
                          11,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(r.$3, style: AppText.ui(14, FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            if (r != rows.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  /// Placeholder for the itinerary / API recommendations module.
  Widget _recsPlaceholder() {
    return DashedBorderBox(
      color: AppColors.border,
      radius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🧭',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 6),
          Text(
            'Itinerary recommendations',
            textAlign: TextAlign.center,
            style: AppText.ui(13, FontWeight.w700, color: AppColors.navy),
          ),
          const SizedBox(height: 2),
          Text(
            'Places picked for your group will show up here.',
            textAlign: TextAlign.center,
            style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          TaraletsButton.ghost(
            label: 'View Recommendations',
            onPressed: () => context.push(AppRoutes.recommendations),
          ),
        ],
      ),
    );
  }

  Widget _liveUpdatesPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _cardDeco,
      child: Row(
        children: [
          const Text('📡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live group updates',
                  style: AppText.ui(14, FontWeight.w600),
                ),
                const SizedBox(height: 1),
                Text(
                  'Check-ins and delays appear here once live tracking is on.',
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
    );
  }
}

/// Confirm dialog for "Complete Trip" (styled like the Figma modals).
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
              style: AppText.ui(17, FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            Text(
              'This ends the trip for everyone and moves it to Completed.',
              style: AppText.ui(
                12,
                FontWeight.w400,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            TaraletsButton.navy(
              label: 'Complete Trip',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
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
