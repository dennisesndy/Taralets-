import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_card.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../discover/data/discover_places_provider.dart';
import '../../../discover/presentation/screens/place_detail_sheet.dart';
import '../../../../data/manila_places.dart';
import '../../data/itinerary_api_mapper.dart';
import '../../data/models/itinerary_models.dart';
import '../controllers/itinerary_controller.dart';

class ItineraryScreen extends ConsumerStatefulWidget {
  const ItineraryScreen({
    super.key,
    this.tripId,
    this.tripTitle,
    this.tripDateLabel,
    this.initialPlan,
  });

  /// Optional trip context. Used when there is no generated plan yet so the
  /// empty state can send the user back to the group flow.
  final String? tripId;
  final String? tripTitle;
  final String? tripDateLabel;

  /// Real plan returned by the backend. The screen no longer falls back to
  /// mock data when this is null.
  final ItineraryPlan? initialPlan;

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  ItineraryController? _controller;
  String? _activeTripId;
  bool _nearby = false;
  bool _loadingPlan = false;
  bool _savingReview = false;
  bool _savingOrder = false;
  bool _unlockingItinerary = false;
  Timer? _refreshTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _activeTripId = widget.tripId;
    final plan = widget.initialPlan;
    if (plan != null) {
      _controller = ItineraryController(plan: plan);
    }
    if ((_activeTripId?.isNotEmpty ?? false)) {
      _loadSavedItinerary();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _loadSavedItinerary(),
      );
    } else {
      _loadingPlan = true;
      Future.microtask(_loadMostRecentSavedItinerary);
    }
  }

  String? get _tripId => _activeTripId;

  Future<void> _loadMostRecentSavedItinerary() async {
    if (_controller != null) return;
    if (!_loadingPlan) setState(() => _loadingPlan = true);
    try {
      final trips = await ref.read(myTripsProvider.future);
      for (final trip in trips) {
        if (!mounted || _tripId != null) return;
        try {
          final data = await ref
              .read(tripRepositoryProvider)
              .getItinerary(trip.id);
          if (!mounted) return;
          _activeTripId = trip.id;
          _controller = ItineraryController(plan: itineraryPlanFromApi(data));
          _refreshTimer?.cancel();
          _refreshTimer = Timer.periodic(
            const Duration(seconds: 2),
            (_) => _loadSavedItinerary(),
          );
          break;
        } on TripException {
          // Try the next trip; the current one may not have an itinerary yet.
        }
      }
    } catch (_) {
      // Keep the empty state available if the trips list cannot be loaded.
    } finally {
      if (mounted) setState(() => _loadingPlan = false);
    }
  }

  @override
  void didUpdateWidget(covariant ItineraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final plan = widget.initialPlan;

    if (oldWidget.tripId != widget.tripId &&
        (widget.tripId?.isNotEmpty ?? false)) {
      _activeTripId = widget.tripId;
      _loadSavedItinerary();
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _loadSavedItinerary(),
      );
    }

    if (plan == null) {
      if (oldWidget.initialPlan != null) {
        _controller?.dispose();
        _controller = null;
      }
      return;
    }

    if (_controller == null || !identical(oldWidget.initialPlan, plan)) {
      _controller?.dispose();
      _controller = ItineraryController(plan: plan);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadSavedItinerary() async {
    final tripId = _tripId;
    if (tripId == null ||
        tripId.isEmpty ||
        _loadingPlan ||
        _savingReview ||
        _savingOrder ||
        _unlockingItinerary) {
      return;
    }
    _loadingPlan = true;
    try {
      final data = await ref.read(tripRepositoryProvider).getItinerary(tripId);
      if (!mounted) return;
      final plan = itineraryPlanFromApi(data);
      if (_controller == null) {
        _controller = ItineraryController(plan: plan);
      } else {
        _controller!.updatePlan(plan);
      }
      setState(() {});
    } on TripException {
      // The empty state is expected before the first itinerary is generated.
    } finally {
      _loadingPlan = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _reviewCurrentUser() async {
    final tripId = _tripId;
    final controller = _controller;
    if (tripId == null || controller == null || _savingReview) return;
    final me = controller.plan.members
        .where((member) => member.isCurrentUser)
        .firstOrNull;
    if (me == null) return;
    setState(() => _savingReview = true);
    try {
      final data = await ref
          .read(tripRepositoryProvider)
          .reviewItinerary(tripId, !me.reviewed);
      if (!mounted) return;
      controller.updatePlan(itineraryPlanFromApi(data));
    } on TripException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  Future<void> _reorderStops(int dayNumber, int oldIndex, int newIndex) async {
    final tripId = _tripId;
    final controller = _controller;
    if (tripId == null || controller == null || _savingOrder) return;
    setState(() => _savingOrder = true);
    controller.reorderStops(dayNumber, oldIndex, newIndex);
    try {
      final data = await ref
          .read(tripRepositoryProvider)
          .reorderItinerary(
            tripId,
            controller.plan.stops.map((stop) => stop.placeId).toList(),
          );
      if (mounted) controller.updatePlan(itineraryPlanFromApi(data));
    } on TripException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        _savingOrder = false;
        await _loadSavedItinerary();
      }
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Future<void> _confirmItinerary() async {
    final tripId = _tripId;
    if (tripId == null) return;
    setState(() => _savingReview = true);
    try {
      final data = await ref.read(tripRepositoryProvider).lockItinerary(tripId);
      if (mounted) _controller?.updatePlan(itineraryPlanFromApi(data));
    } on TripException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  Future<void> _editFinalizedItinerary() async {
    final tripId = _tripId;
    if (tripId == null || _unlockingItinerary) return;
    setState(() => _unlockingItinerary = true);
    try {
      final data = await ref
          .read(tripRepositoryProvider)
          .unlockItinerary(tripId);
      if (mounted) _controller?.updatePlan(itineraryPlanFromApi(data));
    } on TripException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _unlockingItinerary = false);
    }
  }

  Future<void> _addNearbyPlace(Place place) async {
    final tripId = _tripId;
    if (tripId == null || tripId.isEmpty) return;
    try {
      final data = await ref
          .read(tripRepositoryProvider)
          .addItineraryStop(tripId, place.id);
      if (!mounted) return;
      _controller?.updatePlan(itineraryPlanFromApi(data));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${place.name} added to the itinerary. Group review has reopened.',
          ),
        ),
      );
    } on TripException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _viewItinerary() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.trips);
    }
  }

  void _openRouteSelection() {
    final plan = _controller?.plan;
    if (plan == null || plan.stops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add stops before selecting a route.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RouteSelectionSheet(stop: plan.stops.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      if (_loadingPlan) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      return _NoItineraryState(tripId: _tripId, onBack: _handleBack);
    }

    return ColoredBox(
      color: AppColors.bg,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final plan = controller.plan;

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  plan: plan,
                  status: controller.status,
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
                            onTimeline: () => setState(() => _nearby = false),
                            onNearby: () => setState(() => _nearby = true),
                          ),
                          const SizedBox(height: 14),
                          if (_nearby)
                            _NearbySpotsView(
                              stops: plan.stops,
                              editable:
                                  plan.status != ItineraryStatus.finalized &&
                                  (_tripId?.isNotEmpty ?? false),
                              onAddPlace: _addNearbyPlace,
                            )
                          else
                            _TimelineView(
                              stops: plan.stops,
                              days: plan.days,
                              editable:
                                  plan.status != ItineraryStatus.finalized &&
                                  (_tripId?.isNotEmpty ?? false),
                              onReorderDay: _reorderStops,
                            ),
                          const SizedBox(height: 18),
                          _GroupReviewCard(
                            plan: plan,
                            confirmed: controller.confirmed,
                            onToggleReview: _savingReview
                                ? () {}
                                : _reviewCurrentUser,
                            onConfirm: _confirmItinerary,
                            onEditFinalized: _editFinalizedItinerary,
                            onSelectRoute: _openRouteSelection,
                            onViewItinerary: _viewItinerary,
                            isSaving: _savingReview,
                            isUnlocking: _unlockingItinerary,
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

class _NoItineraryState extends StatelessWidget {
  const _NoItineraryState({required this.onBack, this.tripId});

  final VoidCallback onBack;
  final String? tripId;

  @override
  Widget build(BuildContext context) {
    final hasTrip = tripId != null && tripId!.trim().isNotEmpty;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.route_outlined,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No itinerary yet',
                textAlign: TextAlign.center,
                style: AppText.ui(17, FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
              Text(
                'Add places and vote with your group to generate an itinerary '
                "from this trip's members, preferences, and selected places.",
                textAlign: TextAlign.center,
                style: AppText.ui(
                  12.5,
                  FontWeight.w400,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 280,
                child: TaraletsButton.orange(
                  label: hasTrip
                      ? 'Open Group Recommendations'
                      : 'Go to My Trips',
                  onPressed: () {
                    if (hasTrip) {
                      context.push(
                        AppRoutes.recommendations,
                        extra: {'groupId': tripId},
                      );
                    } else {
                      context.go(AppRoutes.trips);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onBack,
                child: Text(
                  'Back',
                  style: AppText.ui(
                    12.5,
                    FontWeight.w700,
                    color: AppColors.muted,
                  ),
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
                    if (plan.days.length > 1)
                      _SummaryChip(
                        icon: Icons.calendar_month_rounded,
                        label: '${plan.days.length} days',
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.ui(10.5, FontWeight.w700, color: Colors.white),
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
  const _TimelineView({
    required this.stops,
    required this.days,
    this.editable = false,
    this.onReorderDay,
  });

  final List<ItineraryStop> stops;
  final List<ItineraryDay> days;
  final bool editable;
  final void Function(int dayNumber, int oldIndex, int newIndex)? onReorderDay;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const _EmptyItinerary();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Your route',
              style: AppText.ui(15, FontWeight.w800, color: AppColors.navy),
            ),
            const Spacer(),
            Text(
              '${stops.length} stops',
              style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
            ),
          ],
        ),
        if (editable) ...[
          const SizedBox(height: 4),
          Text(
            'Press and hold the handle to arrange places',
            style: AppText.ui(10.5, FontWeight.w500, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 10),
        if (editable)
          for (final entry in days.asMap().entries) ...[
            if (days.length > 1) ...[
              const SizedBox(height: 14),
              Text(
                entry.value.label,
                style: AppText.ui(14, FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
            ],
            if (entry.value.stops.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No places planned for this day yet.',
                  style: AppText.ui(
                    12,
                    FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: entry.value.stops.length,
                onReorder: (oldIndex, newIndex) =>
                    onReorderDay?.call(entry.key + 1, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final stop = entry.value.stops[index];
                  return Row(
                    key: ValueKey(stop.id),
                    children: [
                      Expanded(child: _TimelineStop(stop: stop)),
                      ReorderableDelayedDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 18),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: AppColors.muted,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ]
        else if (days.length > 1)
          for (final day in days) ...[
            const SizedBox(height: 14),
            Text(
              day.label,
              style: AppText.ui(14, FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            if (day.stops.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No places planned for this day yet.',
                  style: AppText.ui(
                    12,
                    FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              )
            else
              for (final stop in day.stops) _TimelineStop(stop: stop),
          ]
        else
          for (final stop in stops) _TimelineStop(stop: stop),
        _WrapUpCard(endLabel: stops.last.endLabel),
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
                  child: Text(stop.icon, style: const TextStyle(fontSize: 20)),
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
                  color: stop.isMeetup ? AppColors.navy : AppColors.primary,
                  bg: stop.isMeetup
                      ? AppColors.blueSoft
                      : AppColors.primarySoft,
                ),
                _MetaPill(
                  label: stop.budgetLabel,
                  icon: Icons.payments_outlined,
                ),
                _MetaPill(label: stop.area, icon: Icons.place_outlined),
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
            if (stop.notes != null && stop.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.amberText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      stop.notes!,
                      style: AppText.ui(
                        10.5,
                        FontWeight.w500,
                        color: AppColors.amberText,
                        height: 1.4,
                      ),
                    ),
                  ),
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
          Text(label, style: AppText.ui(9.5, FontWeight.w700, color: color)),
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
                  style: AppText.ui(13, FontWeight.w800, color: AppColors.navy),
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
            style: AppText.mono(11, FontWeight.w700, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nearby spots
// ---------------------------------------------------------------------------

class _NearbySpotsView extends ConsumerWidget {
  const _NearbySpotsView({
    required this.stops,
    required this.editable,
    required this.onAddPlace,
  });

  final List<ItineraryStop> stops;
  final bool editable;
  final ValueChanged<Place> onAddPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stops.isEmpty) return const _EmptyItinerary();
    return ref
        .watch(discoverPlacesProvider)
        .when(
          loading: () {
            final knownPins = _pinsFromStops(stops);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NearbyMapHeader(stopCount: stops.length),
                const SizedBox(height: 10),
                if (knownPins.isNotEmpty)
                  _ItineraryNearbyMap(
                    stops: knownPins,
                    nearby: const [],
                    center: _centerForPins(knownPins),
                    editable: editable,
                    onAddPlace: onAddPlace,
                  )
                else
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(child: Text('Loading…')),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Loading…',
                  style: AppText.ui(
                    11,
                    FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            );
          },
          error: (error, stack) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NearbyMapHeader(stopCount: stops.length),
              const SizedBox(height: 10),
              if (_pinsFromStops(stops).isNotEmpty)
                _ItineraryNearbyMap(
                  stops: _pinsFromStops(stops),
                  nearby: const [],
                  center: _centerForPins(_pinsFromStops(stops)),
                  editable: editable,
                  onAddPlace: onAddPlace,
                ),
              const SizedBox(height: 10),
              Text(
                'Nearby places could not be loaded.',
                style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => ref.invalidate(discoverPlacesProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry nearby places'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                  ),
                ),
              ),
            ],
          ),
          data: (places) {
            final placesById = {for (final place in places) place.id: place};
            final resolvedStops = <_StopPin>[];
            for (final stop in stops) {
              final place =
                  placesById[stop.placeId] ??
                  places
                      .where(
                        (candidate) =>
                            _normalizedPlaceName(candidate.name) ==
                            _normalizedPlaceName(stop.name),
                      )
                      .firstOrNull;
              final lat = stop.latitude != null && stop.latitude != 0
                  ? stop.latitude
                  : place?.lat;
              final lng = stop.longitude != null && stop.longitude != 0
                  ? stop.longitude
                  : place?.lng;
              if (lat != null && lng != null && lat != 0 && lng != 0) {
                resolvedStops.add(_StopPin(stop, LatLng(lat, lng)));
              }
            }
            if (resolvedStops.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NearbyMapHeader(stopCount: stops.length),
                  const SizedBox(height: 10),
                  Text(
                    'Map locations are unavailable for these itinerary stops.',
                    style: AppText.ui(
                      11,
                      FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              );
            }
            final center = _centerForPins(resolvedStops);
            final stopIds = stops.map((stop) => stop.placeId).toSet();
            final nearby =
                places.where((place) {
                  if (stopIds.contains(place.id) ||
                      place.lat == 0 ||
                      place.lng == 0) {
                    return false;
                  }
                  return resolvedStops.any(
                    (stop) =>
                        Geolocator.distanceBetween(
                          stop.point.latitude,
                          stop.point.longitude,
                          place.lat,
                          place.lng,
                        ) <=
                        2000,
                  );
                }).toList()..sort(
                  (a, b) => _distanceFromRoute(
                    a,
                    resolvedStops,
                  ).compareTo(_distanceFromRoute(b, resolvedStops)),
                );
            final visibleNearby = nearby.take(5).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NearbyMapHeader(stopCount: stops.length),
                const SizedBox(height: 10),
                _ItineraryNearbyMap(
                  stops: resolvedStops,
                  nearby: visibleNearby,
                  center: center,
                  editable: editable,
                  onAddPlace: onAddPlace,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Nearby places',
                      style: AppText.ui(
                        14,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Within 2 km · ${nearby.length} places · ${visibleNearby.length} map pins',
                      style: AppText.ui(
                        10.5,
                        FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (visibleNearby.isEmpty)
                  Text(
                    'No other places were found near these itinerary stops.',
                    style: AppText.ui(
                      11,
                      FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  )
                else
                  for (final place in visibleNearby.take(5)) ...[
                    _NearbyPlaceTile(
                      place: place,
                      distanceKm:
                          _distanceFromRoute(place, resolvedStops) / 1000,
                      onTap: () => showPlaceDetail(
                        context,
                        place,
                        onAddToTrip: editable
                            ? () async => onAddPlace(place)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 7),
                  ],
              ],
            );
          },
        );
  }
}

String _normalizedPlaceName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

class _StopPin {
  const _StopPin(this.stop, this.point);

  final ItineraryStop stop;
  final LatLng point;
}

List<_StopPin> _pinsFromStops(List<ItineraryStop> stops) => [
  for (final stop in stops)
    if (stop.latitude != null &&
        stop.longitude != null &&
        stop.latitude != 0 &&
        stop.longitude != 0)
      _StopPin(stop, LatLng(stop.latitude!, stop.longitude!)),
];

LatLng _centerForPins(List<_StopPin> stops) => LatLng(
  stops.map((stop) => stop.point.latitude).reduce((a, b) => a + b) /
      stops.length,
  stops.map((stop) => stop.point.longitude).reduce((a, b) => a + b) /
      stops.length,
);

double _distanceFromRoute(Place place, List<_StopPin> stops) {
  var nearest = double.infinity;
  for (final stop in stops) {
    final distance = Geolocator.distanceBetween(
      stop.point.latitude,
      stop.point.longitude,
      place.lat,
      place.lng,
    );
    if (distance < nearest) nearest = distance;
  }
  return nearest;
}

class _NearbyMapHeader extends StatelessWidget {
  const _NearbyMapHeader({required this.stopCount});
  final int stopCount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            'Stops and nearby places',
            style: AppText.ui(15, FontWeight.w800, color: AppColors.navy),
          ),
          const Spacer(),
          Text(
            '$stopCount itinerary stops',
            style: AppText.ui(10.5, FontWeight.w600, color: AppColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Your itinerary is highlighted. Other places within 2 km are shown as nearby options.',
        style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
      ),
    ],
  );
}

class _ItineraryNearbyMap extends StatelessWidget {
  const _ItineraryNearbyMap({
    required this.stops,
    required this.nearby,
    required this.center,
    required this.editable,
    required this.onAddPlace,
    this.fullScreen = false,
  });
  final List<_StopPin> stops;
  final List<Place> nearby;
  final LatLng center;
  final bool editable;
  final ValueChanged<Place> onAddPlace;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final route = stops.map((stop) => stop.point).toList();
    final routesByDay = <int, List<LatLng>>{};
    for (final stop in stops) {
      routesByDay.putIfAbsent(stop.stop.dayNumber, () => []).add(stop.point);
    }
    final groupedStops = <List<int>>[];
    for (var i = 0; i < stops.length; i++) {
      final group = groupedStops
          .where(
            (indices) =>
                Geolocator.distanceBetween(
                  stops[indices.first].point.latitude,
                  stops[indices.first].point.longitude,
                  stops[i].point.latitude,
                  stops[i].point.longitude,
                ) <
                35,
          )
          .firstOrNull;
      if (group == null) {
        groupedStops.add([i]);
      } else {
        group.add(i);
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: fullScreen ? double.infinity : 520,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13.5,
                initialCameraFit: route.length > 1
                    ? CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(route),
                        padding: const EdgeInsets.all(48),
                      )
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.taralets.app',
                ),
                if (routesByDay.values.any((points) => points.length > 1))
                  PolylineLayer(
                    polylines: [
                      for (final points in routesByDay.values)
                        if (points.length > 1)
                          Polyline(
                            points: points,
                            color: AppColors.primary.withValues(alpha: 0.78),
                            strokeWidth: 4,
                          ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final place in nearby)
                      Marker(
                        point: LatLng(place.lat, place.lng),
                        width: 25,
                        height: 25,
                        child: GestureDetector(
                          onTap: () => showPlaceDetail(
                            context,
                            place,
                            onAddToTrip: editable
                                ? () async => onAddPlace(place)
                                : null,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _nearbyMarkerColor(place),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              _nearbyMarkerIcon(place.category),
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    for (final stopGroup in groupedStops)
                      for (
                        var memberIndex = 0;
                        memberIndex < stopGroup.length;
                        memberIndex++
                      )
                        Marker(
                          point: stopGroup.length == 1
                              ? route[stopGroup.first]
                              : _fannedMarkerPoint(
                                  route[stopGroup.first],
                                  memberIndex,
                                  stopGroup.length,
                                ),
                          width: 42,
                          height: 48,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                constraints: const BoxConstraints(
                                  minWidth: 34,
                                  minHeight: 34,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${stopGroup[memberIndex] + 1}',
                                  style: AppText.ui(
                                    13,
                                    FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(
                                width: 3,
                                height: 9,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Itinerary',
                      style: AppText.ui(
                        10,
                        FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.add_circle_outline,
                      size: 13,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Nearby',
                      style: AppText.ui(
                        10,
                        FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!fullScreen)
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.96),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: 'Open full-screen map',
                    onPressed: () => _openFullScreenMap(context),
                    icon: const Icon(Icons.fullscreen_rounded),
                    color: AppColors.navy,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenMap(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Itinerary map'),
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: _NearbyMapHeader(stopCount: stops.length),
                ),
                Expanded(
                  child: _ItineraryNearbyMap(
                    stops: stops,
                    nearby: nearby,
                    center: center,
                    editable: editable,
                    onAddPlace: onAddPlace,
                    fullScreen: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

LatLng _fannedMarkerPoint(LatLng center, int index, int count) {
  final angle = (2 * math.pi * index / count) - (math.pi / 2);
  const offsetMeters = 24.0;
  final latitudeOffset = math.cos(angle) * offsetMeters / 111320;
  final longitudeScale = math.cos(center.latitude * math.pi / 180).abs();
  final longitudeOffset =
      math.sin(angle) *
      offsetMeters /
      (111320 * (longitudeScale < 0.01 ? 0.01 : longitudeScale));
  return LatLng(
    center.latitude + latitudeOffset,
    center.longitude + longitudeOffset,
  );
}

Color _nearbyMarkerColor(Place place) {
  const colors = [
    Color(0xFFE95D27),
    Color(0xFF2F80ED),
    Color(0xFF27AE60),
    Color(0xFF9B51E0),
    Color(0xFFEB5757),
    Color(0xFF00A6A6),
  ];
  return colors[place.clusterId.abs() % colors.length];
}

IconData _nearbyMarkerIcon(String category) {
  final value = category.toLowerCase();
  if (value.contains('food') ||
      value.contains('cafe') ||
      value.contains('restaurant')) {
    return Icons.restaurant_rounded;
  }
  if (value.contains('shopping') || value.contains('retail')) {
    return Icons.shopping_bag_rounded;
  }
  if (value.contains('church') || value.contains('religious')) {
    return Icons.church_rounded;
  }
  if (value.contains('museum') || value.contains('historical')) {
    return Icons.account_balance_rounded;
  }
  if (value.contains('park') || value.contains('nature')) {
    return Icons.park_rounded;
  }
  return Icons.place_rounded;
}

class _NearbyPlaceTile extends StatelessWidget {
  const _NearbyPlaceTile({
    required this.place,
    required this.distanceKm,
    required this.onTap,
  });
  final Place place;
  final double distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.add_location_alt_outlined,
              size: 18,
              color: AppColors.muted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(
                      11.5,
                      FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    place.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(
                      10,
                      FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              distanceKm < 0.1
                  ? '${(distanceKm * 1000).round()} m'
                  : '${distanceKm.toStringAsFixed(1)} km',
              style: AppText.ui(10, FontWeight.w600, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
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
    required this.onEditFinalized,
    required this.onSelectRoute,
    required this.onViewItinerary,
    required this.isSaving,
    required this.isUnlocking,
  });

  final ItineraryPlan plan;
  final bool confirmed;
  final VoidCallback onToggleReview;
  final VoidCallback onConfirm;
  final VoidCallback onEditFinalized;
  final VoidCallback onSelectRoute;
  final VoidCallback onViewItinerary;
  final bool isSaving;
  final bool isUnlocking;

  @override
  Widget build(BuildContext context) {
    final reviewed = plan.reviewedCount;
    final total = plan.members.length;
    final remaining = total - reviewed;
    final currentMember = plan.members
        .where((member) => member.isCurrentUser)
        .firstOrNull;
    final currentUserIsLeader = currentMember?.isLeader ?? false;

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
                      confirmed ? 'Group confirmed' : 'Group review',
                      style: AppText.ui(
                        14,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      confirmed
                          ? 'All members reviewed. The plan is locked.'
                          : '$reviewed of $total members reviewed',
                      style: AppText.ui(
                        11,
                        FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _ReviewProgressPill(reviewed: reviewed, total: total),
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
          if (confirmed) ...[
            _ConfirmedBanner(
              onSelectRoute: onSelectRoute,
              onViewItinerary: onViewItinerary,
            ),
            if (currentUserIsLeader && (plan.tripId?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              TaraletsButton.ghost(
                label: isUnlocking ? 'Loading…' : 'Edit itinerary',
                onPressed: isUnlocking ? null : onEditFinalized,
              ),
              const SizedBox(height: 6),
              Text(
                'Editing will reopen group review and ask everyone to confirm the changes.',
                textAlign: TextAlign.center,
                style: AppText.ui(
                  10.5,
                  FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ] else if (reviewed == total && currentUserIsLeader)
            TaraletsButton.orange(
              label: '🔒 Lock Final Itinerary',
              isLoading: isSaving,
              onPressed: isSaving ? null : onConfirm,
            )
          else if (reviewed == total)
            const _WaitingLeaderBanner()
          else ...[
            if (plan.members.any(
              (member) => member.isCurrentUser && !member.reviewed,
            )) ...[
              TaraletsButton.ghost(
                label: 'Mark itinerary as reviewed',
                onPressed: isSaving ? null : onToggleReview,
              ),
              const SizedBox(height: 10),
            ],
            _WaitingBanner(remaining: remaining),
          ],
        ],
      ),
    );
  }
}

class _WaitingLeaderBanner extends StatelessWidget {
  const _WaitingLeaderBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.blueSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.lock_clock_rounded, size: 17, color: AppColors.navy),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'You reviewed the plan. Waiting for the trip leader to lock the itinerary.',
            style: AppText.ui(11, FontWeight.w600, color: AppColors.navy),
          ),
        ),
      ],
    ),
  );
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
                  style: AppText.ui(13, FontWeight.w700, color: AppColors.text),
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
          interactive: false,
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
            reviewed ? Icons.check_circle_rounded : Icons.schedule_rounded,
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
  const _ReviewProgressPill({required this.reviewed, required this.total});

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
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
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
  const _ConfirmedBanner({
    required this.onSelectRoute,
    required this.onViewItinerary,
  });

  final VoidCallback onSelectRoute;
  final VoidCallback onViewItinerary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
        ),
        const SizedBox(height: 10),
        Text(
          'Review the full plan above, then choose your route.',
          textAlign: TextAlign.center,
          style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        TaraletsButton.orange(
          label: 'View Itinerary',
          onPressed: onViewItinerary,
        ),
        const SizedBox(height: 8),
        TaraletsButton.ghost(label: 'Select Route', onPressed: onSelectRoute),
      ],
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
            style: AppText.ui(15, FontWeight.w800, color: AppColors.navy),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      children: [for (final tag in tags) _TagChip(tag: tag)],
                    ),
                  ],
                  if (stop.notes != null && stop.notes!.isNotEmpty) ...[
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

class _RouteSelectionSheet extends StatelessWidget {
  const _RouteSelectionSheet({required this.stop});

  final ItineraryStop stop;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.route_rounded,
                          size: 24,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select your route',
                              style: AppText.ui(
                                17,
                                FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Plan your departure to the first stop.',
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
                  TaraletsCard(
                    padding: const EdgeInsets.all(14),
                    border: Border.all(color: AppColors.border),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const _MetaPill(
                              label: 'FIRST STOP',
                              icon: Icons.flag_rounded,
                              color: AppColors.navy,
                              bg: AppColors.blueSoft,
                            ),
                            const Spacer(),
                            Text(
                              stop.startLabel,
                              style: AppText.mono(
                                11,
                                FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          stop.name,
                          style: AppText.ui(
                            15,
                            FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${stop.category} · ${stop.area}',
                          style: AppText.ui(
                            11,
                            FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _MetaPill(
                              label: 'Target ${stop.startLabel}',
                              icon: Icons.schedule_rounded,
                            ),
                            const _MetaPill(
                              label: 'Public transport + walk',
                              icon: Icons.directions_transit_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Route options coming next',
                    style: AppText.ui(
                      12,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MetaPill(
                        label: 'Fastest',
                        icon: Icons.bolt_rounded,
                        color: AppColors.primary,
                        bg: AppColors.primarySoft,
                      ),
                      _MetaPill(
                        label: 'Budget',
                        icon: Icons.payments_outlined,
                        color: AppColors.greenText,
                        bg: AppColors.greenSoft,
                      ),
                      _MetaPill(
                        label: 'Fewest transfers',
                        icon: Icons.swap_horiz_rounded,
                        color: AppColors.navy,
                        bg: AppColors.blueSoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amberSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.amberText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is the entry point for route selection. '
                            'The Departure Schedule and route options will be '
                            'connected in the next step.',
                            style: AppText.ui(
                              11.5,
                              FontWeight.w500,
                              color: AppColors.amberText,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TaraletsButton.navy(
                    label: 'Got it',
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
              style: AppText.ui(11.5, FontWeight.w500, color: AppColors.muted),
            ),
          ),
          Text(
            value,
            style: AppText.ui(11.5, FontWeight.w700, color: AppColors.navy),
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
            style: AppText.ui(9.5, FontWeight.w700, color: tag.color),
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
        style: AppText.ui(9.5, FontWeight.w700, color: AppColors.muted),
      ),
    );
  }
}
