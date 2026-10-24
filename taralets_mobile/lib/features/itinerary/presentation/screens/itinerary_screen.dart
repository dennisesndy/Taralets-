import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_card.dart';
import '../../data/models/itinerary_models.dart';
import '../controllers/itinerary_controller.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({
    super.key,
    this.tripTitle,
    this.tripDateLabel,
    this.initialPlan,
  });

  /// Optional trip context. Kept nullable so the current router entry can
  /// keep using mock data until the itinerary is wired to a trip.
  final String? tripTitle;
  final String? tripDateLabel;

  /// Generated from the selected places and group votes. Falls back to the
  /// local mock plan when the screen is opened from Home/Trips.
  final ItineraryPlan? initialPlan;

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  late final ItineraryController _controller;
  bool _nearby = false;

  @override
  void initState() {
    super.initState();
    _controller = ItineraryController(plan: widget.initialPlan);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.trips);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bg,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final plan = _controller.plan;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  plan: plan,
                  status: _controller.status,
                  tripTitle: widget.tripTitle,
                  tripDateLabel: widget.tripDateLabel,
                  onBack: _handleBack,
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ViewToggle(
                            nearby: _nearby,
                            onTimeline: () =>
                                setState(() => _nearby = false),
                            onNearby: () =>
                                setState(() => _nearby = true),
                          ),
                          const SizedBox(height: 14),
                          if (_nearby)
                            _NearbySpotsView(stops: plan.stops)
                          else
                            _TimelineView(stops: plan.stops),
                          const SizedBox(height: 18),
                          _GroupReviewCard(
                            plan: plan,
                            confirmed: _controller.confirmed,
                            onToggleReview:
                                _controller.toggleCurrentUserReviewed,
                            onConfirm: _controller.confirm,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.plan,
    required this.status,
    required this.onBack,
    this.tripTitle,
    this.tripDateLabel,
  });

  final ItineraryPlan plan;
  final ItineraryStatus status;
  final VoidCallback onBack;
  final String? tripTitle;
  final String? tripDateLabel;

  @override
  Widget build(BuildContext context) {
    final title = tripTitle ?? plan.title;
    final dateLabel = tripDateLabel ?? plan.dateLabel;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, Color(0xFF283D66)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BackButton(onTap: onBack),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Group Itinerary',
                        style: AppText.ui(
                          13,
                          FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    _StatusChip(status: status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(
                    23,
                    FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$dateLabel · ${plan.startLabel} – ${plan.endLabel}',
                  style: AppText.ui(
                    12,
                    FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _SummaryChip(
                      icon: Icons.place_rounded,
                      label: '${plan.totalStops} stops',
                    ),
                    _SummaryChip(
                      icon: Icons.schedule_rounded,
                      label: plan.spanLabel,
                    ),
                    _SummaryChip(
                      icon: Icons.payments_outlined,
                      label: plan.totalBudgetLabel,
                    ),
                    _SummaryChip(
                      icon: Icons.directions_walk_rounded,
                      label: '${plan.totalTravelMinutes} min travel',
                    ),
                    _SummaryChip(
                      icon: Icons.speed_rounded,
                      label: '${plan.pace} pace',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Built from ${plan.groupPreferences.join(' · ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          10.5,
                          FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ItineraryStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ItineraryStatus.draft => const Color(0xFF93C5FD),
      ItineraryStatus.review => AppColors.gold,
      ItineraryStatus.finalized => const Color(0xFF6EE7B7),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: AppText.ui(
              10,
              FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.ui(
              10.5,
              FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// View toggle
// ---------------------------------------------------------------------------

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.nearby,
    required this.onTimeline,
    required this.onNearby,
  });

  final bool nearby;
  final VoidCallback onTimeline;
  final VoidCallback onNearby;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ViewTab(
            label: 'Timeline',
            icon: Icons.timeline_rounded,
            selected: !nearby,
            onTap: onTimeline,
          ),
          _ViewTab(
            label: 'Nearby Spots',
            icon: Icons.map_outlined,
            selected: nearby,
            onTap: onNearby,
          ),
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? AppColors.primarySoft : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.ui(
                  11.5,
                  FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.stops});

  final List<ItineraryStop> stops;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const _EmptyItinerary();

    final periods = _buildPeriods(stops);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Your route',
              style: AppText.ui(
                15,
                FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const Spacer(),
            Text(
              '${stops.length} stops',
              style: AppText.ui(
                11,
                FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final period in periods) ...[
          _PeriodHeader(period: period),
          const SizedBox(height: 8),
          for (final stop in period.stops) _TimelineStop(stop: stop),
          const SizedBox(height: 6),
        ],
        _WrapUpCard(endLabel: stops.last.endLabel),
      ],
    );
  }
}

class _PeriodData {
  const _PeriodData({
    required this.label,
    required this.icon,
    required this.stops,
  });

  final String label;
  final String icon;
  final List<ItineraryStop> stops;
}

List<_PeriodData> _buildPeriods(List<ItineraryStop> stops) {
  final morning = <ItineraryStop>[];
  final afternoon = <ItineraryStop>[];
  final evening = <ItineraryStop>[];

  for (final stop in stops) {
    final hour = stop.startTime.hour;
    if (hour < 12) {
      morning.add(stop);
    } else if (hour < 17) {
      afternoon.add(stop);
    } else {
      evening.add(stop);
    }
  }

  return [
    if (morning.isNotEmpty)
      _PeriodData(label: 'Morning', icon: '☀️', stops: morning),
    if (afternoon.isNotEmpty)
      _PeriodData(label: 'Afternoon', icon: '🌤', stops: afternoon),
    if (evening.isNotEmpty)
      _PeriodData(label: 'Evening', icon: '🌆', stops: evening),
  ];
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.period});

  final _PeriodData period;

  @override
  Widget build(BuildContext context) {
    final first = period.stops.first;
    final last = period.stops.last;

    return Row(
      children: [
        Text(period.icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              period.label,
              style: AppText.ui(
                12,
                FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            Text(
              '${first.startLabel} – ${last.endLabel}',
              style: AppText.mono(
                9.5,
                FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: AppColors.border),
        ),
      ],
    );
  }
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({required this.stop});

  final ItineraryStop stop;

  @override
  Widget build(BuildContext context) {
    final dotColor = stop.isMeetup ? AppColors.navy : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stop.travelMinutes > 0)
          Padding(
            padding: const EdgeInsets.only(left: 7, bottom: 6),
            child: Row(
              children: [
                Container(width: 1, height: 18, color: AppColors.border),
                const SizedBox(width: 10),
                const Icon(
                  Icons.directions_walk_rounded,
                  size: 13,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  stop.travelLabel,
                  style: AppText.ui(
                    10,
                    FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 19),
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _StopCard(stop: stop)),
          ],
        ),
      ],
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop});

  final ItineraryStop stop;

  @override
  Widget build(BuildContext context) {
    final tags = _tagsFor(stop);
    final visibleTags = tags.take(3).toList();
    final hiddenTagCount = tags.length - visibleTags.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TaraletsCard(
        padding: const EdgeInsets.all(14),
        border: Border.all(color: AppColors.border),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: stop.isMeetup
                        ? AppColors.blueSoft
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stop.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              stop.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.ui(
                                14,
                                FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          if (!stop.isMeetup) ...[
                            const SizedBox(width: 6),
                            _ScorePill(score: stop.groupScoreLabel),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stop.timeRange,
                        style: AppText.mono(
                          10.5,
                          FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetaPill(
                  label: stop.category,
                  icon: stop.isMeetup
                      ? Icons.flag_rounded
                      : Icons.category_outlined,
                  color: stop.isMeetup
                      ? AppColors.navy
                      : AppColors.primary,
                  bg: stop.isMeetup
                      ? AppColors.blueSoft
                      : AppColors.primarySoft,
                ),
                _MetaPill(
                  label: stop.budgetLabel,
                  icon: Icons.payments_outlined,
                ),
                _MetaPill(
                  label: stop.area,
                  icon: Icons.place_outlined,
                ),
              ],
            ),
            if (visibleTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in visibleTags) _TagChip(tag: tag),
                  if (hiddenTagCount > 0)
                    _OverflowTag(label: '+$hiddenTagCount'),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showStopDetails(context, stop),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: AppText.ui(
                          10.5,
                          FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: AppColors.navy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final String score;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Group match score',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.greenSoft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups_rounded,
              size: 12,
              color: AppColors.greenText,
            ),
            const SizedBox(width: 3),
            Text(
              score,
              style: AppText.ui(
                10,
                FontWeight.w800,
                color: AppColors.greenText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    this.icon,
    this.color = AppColors.muted,
    this.bg = const Color(0xFFF7F8FA),
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppText.ui(
              9.5,
              FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WrapUpCard extends StatelessWidget {
  const _WrapUpCard({required this.endLabel});

  final String endLabel;

  @override
  Widget build(BuildContext context) {
    return TaraletsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: Border.all(color: AppColors.border),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text('🏠', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wrap-up & head home',
                  style: AppText.ui(
                    13,
                    FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Trip ends · Return commute guide ready.',
                  style: AppText.ui(
                    11,
                    FontWeight.w400,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            endLabel,
            style: AppText.mono(
              11,
              FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nearby spots
// ---------------------------------------------------------------------------

class _NearbySpotsView extends StatelessWidget {
  const _NearbySpotsView({required this.stops});

  final List<ItineraryStop> stops;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const _EmptyItinerary();

    final groups = <String, List<ItineraryStop>>{};
    for (final stop in stops) {
      groups.putIfAbsent(stop.area, () => []).add(stop);
    }
    final entries = groups.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Nearby spots',
              style: AppText.ui(
                15,
                FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const Spacer(),
            Text(
              '${entries.length} areas',
              style: AppText.ui(
                11,
                FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Your stops, grouped by neighborhood.',
          style: AppText.ui(
            11,
            FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < entries.length; i++) ...[
          _ClusterCard(
            area: entries[i].key,
            stops: entries[i].value,
            index: i,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ClusterStyle {
  const _ClusterStyle(this.color, this.bg);

  final Color color;
  final Color bg;
}

_ClusterStyle _clusterStyle(int index) {
  const styles = [
    _ClusterStyle(AppColors.primary, AppColors.primarySoft),
    _ClusterStyle(AppColors.navy, AppColors.blueSoft),
    _ClusterStyle(AppColors.green, AppColors.greenSoft),
    _ClusterStyle(AppColors.purple, Color(0xFFF3EEFF)),
  ];
  return styles[index % styles.length];
}

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({
    required this.area,
    required this.stops,
    required this.index,
  });

  final String area;
  final List<ItineraryStop> stops;
  final int index;

  @override
  Widget build(BuildContext context) {
    final style = _clusterStyle(index);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: style.color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: style.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Explore: $area',
                  style: AppText.ui(
                    12,
                    FontWeight.w800,
                    color: style.color,
                  ),
                ),
              ),
              Text(
                '${stops.length} ${stops.length == 1 ? 'stop' : 'stops'}',
                style: AppText.ui(
                  10,
                  FontWeight.w600,
                  color: style.color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final stop in stops)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: style.color.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stop.icon,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        stop.name,
                        style: AppText.ui(
                          11,
                          FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        stop.startLabel,
                        style: AppText.mono(
                          9.5,
                          FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group review
// ---------------------------------------------------------------------------

class _GroupReviewCard extends StatelessWidget {
  const _GroupReviewCard({
    required this.plan,
    required this.confirmed,
    required this.onToggleReview,
    required this.onConfirm,
  });

  final ItineraryPlan plan;
  final bool confirmed;
  final VoidCallback onToggleReview;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final reviewed = plan.reviewedCount;
    final total = plan.members.length;
    final remaining = total - reviewed;

    return TaraletsCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppColors.border),
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
                      'Group review',
                      style: AppText.ui(
                        14,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$reviewed of $total members reviewed',
                      style: AppText.ui(
                        11,
                        FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _ReviewProgressPill(
                reviewed: reviewed,
                total: total,
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final member in plan.members) ...[
            _MemberReviewRow(
              member: member,
              confirmed: confirmed,
              onToggle: onToggleReview,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          if (confirmed)
            const _ConfirmedBanner()
          else if (reviewed == total)
            TaraletsButton.orange(
              label: '🔒 Confirm Final Itinerary',
              onPressed: onConfirm,
            )
          else
            _WaitingBanner(remaining: remaining),
        ],
      ),
    );
  }
}

class _MemberReviewRow extends StatelessWidget {
  const _MemberReviewRow({
    required this.member,
    required this.confirmed,
    required this.onToggle,
  });

  final ItineraryMember member;
  final bool confirmed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Avatar(name: member.name, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(
                    13,
                    FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (member.isCurrentUser) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blueSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'You',
                    style: AppText.ui(
                      9,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _ReviewStatusChip(
          reviewed: member.reviewed,
          interactive: member.isCurrentUser && !confirmed,
          onTap: onToggle,
        ),
      ],
    );
  }
}

class _ReviewStatusChip extends StatelessWidget {
  const _ReviewStatusChip({
    required this.reviewed,
    required this.interactive,
    required this.onTap,
  });

  final bool reviewed;
  final bool interactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: reviewed ? AppColors.greenSoft : AppColors.amberSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reviewed
                ? Icons.check_circle_rounded
                : Icons.schedule_rounded,
            size: 12,
            color: reviewed ? AppColors.greenText : AppColors.amberText,
          ),
          const SizedBox(width: 3),
          Text(
            reviewed ? 'Reviewed' : 'Pending',
            style: AppText.ui(
              10,
              FontWeight.w700,
              color: reviewed ? AppColors.greenText : AppColors.amberText,
            ),
          ),
        ],
      ),
    );

    if (!interactive) return chip;

    return Tooltip(
      message: 'Tap to mark your review',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

class _ReviewProgressPill extends StatelessWidget {
  const _ReviewProgressPill({
    required this.reviewed,
    required this.total,
  });

  final int reviewed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final complete = reviewed == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: complete ? AppColors.greenSoft : AppColors.blueSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$reviewed/$total',
        style: AppText.ui(
          10.5,
          FontWeight.w800,
          color: complete ? AppColors.greenText : AppColors.navy,
        ),
      ),
    );
  }
}

class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 16,
            color: AppColors.amberText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Waiting for $remaining more '
              '${remaining == 1 ? 'member' : 'members'} to review.',
              style: AppText.ui(
                11,
                FontWeight.w600,
                color: AppColors.amberText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedBanner extends StatelessWidget {
  const _ConfirmedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 18,
            color: AppColors.greenText,
          ),
          const SizedBox(height: 6),
          Text(
            'Itinerary confirmed!',
            style: AppText.ui(
              14,
              FontWeight.w800,
              color: AppColors.greenText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your group plan is ready for trip day.',
            textAlign: TextAlign.center,
            style: AppText.ui(
              11.5,
              FontWeight.w400,
              color: AppColors.greenDeep,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyItinerary extends StatelessWidget {
  const _EmptyItinerary();

  @override
  Widget build(BuildContext context) {
    return TaraletsCard(
      padding: const EdgeInsets.all(24),
      border: Border.all(color: AppColors.border),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.route_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No stops yet',
            style: AppText.ui(
              15,
              FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your group itinerary will appear here once places are selected.',
            textAlign: TextAlign.center,
            style: AppText.ui(
              11.5,
              FontWeight.w500,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stop details sheet
// ---------------------------------------------------------------------------

void _showStopDetails(BuildContext context, ItineraryStop stop) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StopDetailsSheet(stop: stop),
  );
}

class _StopDetailsSheet extends StatelessWidget {
  const _StopDetailsSheet({required this.stop});

  final ItineraryStop stop;

  @override
  Widget build(BuildContext context) {
    final tags = _tagsFor(stop);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: stop.isMeetup
                              ? AppColors.blueSoft
                              : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          stop.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.name,
                              style: AppText.ui(
                                17,
                                FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stop.category} · ${stop.area}',
                              style: AppText.ui(
                                11,
                                FontWeight.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Time',
                    value: stop.timeRange,
                  ),
                  _InfoRow(
                    icon: Icons.timelapse_rounded,
                    label: 'Duration',
                    value: '${stop.durationMinutes} min',
                  ),
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Budget',
                    value: stop.budgetLabel,
                  ),
                  _InfoRow(
                    icon: Icons.directions_walk_rounded,
                    label: 'From previous',
                    value: stop.travelMinutes == 0
                        ? 'Start of route'
                        : stop.travelLabel,
                  ),
                  _InfoRow(
                    icon: Icons.speed_rounded,
                    label: 'Pace',
                    value: stop.pace,
                  ),
                  _InfoRow(
                    icon: Icons.groups_rounded,
                    label: 'Group match',
                    value: stop.groupScoreLabel,
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Group fit',
                      style: AppText.ui(
                        12,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags) _TagChip(tag: tag),
                      ],
                    ),
                  ],
                  if (stop.notes != null &&
                      stop.notes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 16,
                            color: AppColors.amberText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              stop.notes!,
                              style: AppText.ui(
                                11.5,
                                FontWeight.w500,
                                color: AppColors.muted,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TaraletsButton.navy(
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.navy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppText.ui(
                11.5,
                FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ),
          Text(
            value,
            style: AppText.ui(
              11.5,
              FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Preference tags
// ---------------------------------------------------------------------------

class _TagData {
  const _TagData({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
}

List<_TagData> _tagsFor(ItineraryStop stop) {
  return [
    for (final tag in stop.activityTags)
      _TagData(
        label: tag,
        icon: Icons.local_activity_outlined,
        color: AppColors.primary,
        bg: AppColors.primarySoft,
      ),
    for (final tag in stop.dietaryTags)
      _TagData(
        label: tag,
        icon: Icons.restaurant_outlined,
        color: AppColors.greenText,
        bg: AppColors.greenSoft,
      ),
    for (final tag in stop.accessibilityTags)
      _TagData(
        label: tag,
        icon: Icons.accessible_rounded,
        color: AppColors.indigo,
        bg: AppColors.blueSoft,
      ),
  ];
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final _TagData tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tag.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 11, color: tag.color),
          const SizedBox(width: 4),
          Text(
            tag.label,
            style: AppText.ui(
              9.5,
              FontWeight.w700,
              color: tag.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverflowTag extends StatelessWidget {
  const _OverflowTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: AppText.ui(
          9.5,
          FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
