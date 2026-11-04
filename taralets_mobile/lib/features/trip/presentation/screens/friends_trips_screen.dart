import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/back_button_tile.dart';

class FriendsTripsScreen extends ConsumerStatefulWidget {
  const FriendsTripsScreen({super.key});

  @override
  ConsumerState<FriendsTripsScreen> createState() => _FriendsTripsScreenState();
}

class _FriendsTripsScreenState extends ConsumerState<FriendsTripsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _itineraries = [];
  final Set<String> _requesting = {};
  final Set<String> _requested = {};
  Timer? _membershipTimer;
  bool _checkingMembership = false;

  @override
  void initState() {
    super.initState();
    _loadItineraries();
    _membershipTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkApprovedMembership(),
    );
  }

  Future<void> _checkApprovedMembership() async {
    if (!mounted || _requested.isEmpty || _checkingMembership) return;
    _checkingMembership = true;
    try {
      final repository = ref.read(tripRepositoryProvider);
      for (final tripId in _requested.toList()) {
        final status = await repository.getTripJoinRequestStatus(tripId);
        if (status['status']?.toString() == 'accepted') {
          _requested.remove(tripId);
          ref.invalidate(myTripsProvider);
          if (mounted) context.go(AppRoutes.trips);
          return;
        }
      }
    } catch (_) {
      // Keep checking while a join request is still pending.
    } finally {
      _checkingMembership = false;
    }
  }

  @override
  void dispose() {
    _membershipTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadItineraries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(tripRepositoryProvider)
          .getAvailableItineraries();
      if (mounted) {
        setState(() => _itineraries = rows);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load shared itineraries.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestJoin(String tripId) async {
    if (_requesting.contains(tripId) || _requested.contains(tripId)) return;
    setState(() => _requesting.add(tripId));
    try {
      await ref.read(tripRepositoryProvider).requestToJoinTrip(tripId);
      if (!mounted) return;
      setState(() => _requested.add(tripId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent to the trip leader.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is TripException
                  ? error.message
                  : 'Could not send join request.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting.remove(tripId));
    }
  }

  void _createGroup(Map<String, dynamic> row) {
    final trip = Map<String, dynamic>.from(row['trip'] as Map? ?? const {});
    final itinerary = Map<String, dynamic>.from(
      row['itinerary'] as Map? ?? const {},
    );
    context.push(
      AppRoutes.createTrip,
      extra: {
        'locationName':
            trip['meetup_full']?.toString() ??
            trip['meetup']?.toString() ??
            'Plaza Roma, Intramuros',
        'latitude': (trip['latitude'] as num?)?.toDouble() ?? 14.5896,
        'longitude': (trip['longitude'] as num?)?.toDouble() ?? 120.9753,
        'sourceItineraryId': itinerary['itinerary_id']?.toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      leading: BackButtonTile(onTap: () => context.pop()),
      title: Text(
        'Available Itineraries',
        style: AppText.ui(17, FontWeight.w800, color: Colors.white),
      ),
    ),
    body: RefreshIndicator(
      color: AppColors.orange,
      onRefresh: _loadItineraries,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Text(
            'Plans shared by your friends',
            style: AppText.ui(20, FontWeight.w900, color: AppColors.navy),
          ),
          const SizedBox(height: 6),
          Text(
            'Only itineraries shared with friends appear here. You can request to join the original trip or use its itinerary for a new group.',
            style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(34),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.orange),
              ),
            )
          else if (_error != null)
            _NoticeCard(
              message: _error!,
              action: 'Retry',
              onTap: _loadItineraries,
            )
          else if (_itineraries.isEmpty)
            const _NoticeCard(
              message: 'Your friends have not shared an itinerary yet.',
            )
          else
            for (final row in _itineraries) ...[
              _SharedItineraryCard(
                row: row,
                requesting: _requesting.contains(
                  (row['trip'] as Map?)?['id']?.toString(),
                ),
                requested: _requested.contains(
                  (row['trip'] as Map?)?['id']?.toString(),
                ),
                onRequestJoin: () =>
                    _requestJoin((row['trip'] as Map)['id'].toString()),
                onCreateGroup: () => _createGroup(row),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    ),
  );
}

class _SharedItineraryCard extends StatelessWidget {
  const _SharedItineraryCard({
    required this.row,
    required this.requesting,
    required this.requested,
    required this.onRequestJoin,
    required this.onCreateGroup,
  });

  final Map<String, dynamic> row;
  final bool requesting;
  final bool requested;
  final VoidCallback onRequestJoin;
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    final trip = Map<String, dynamic>.from(row['trip'] as Map? ?? const {});
    final itinerary = Map<String, dynamic>.from(
      row['itinerary'] as Map? ?? const {},
    );
    final stops = (itinerary['stops'] as List? ?? const [])
        .whereType<Map>()
        .map((stop) => Map<String, dynamic>.from(stop))
        .toList();
    final canJoin = row['can_join_existing'] == true;
    final owner = row['owner_name']?.toString() ?? 'Friend';
    final tripId = trip['id']?.toString() ?? '';
    final members = (trip['members'] as List? ?? const [])
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member))
        .toList();
    final leader = members.firstWhere(
      (member) => member['is_leader'] == true,
      orElse: () => <String, dynamic>{},
    );
    final leaderPreferences = Map<String, dynamic>.from(
      leader['trip_preferences'] as Map? ?? const {},
    );
    final groupPreferences = Map<String, dynamic>.from(
      trip['group_preferences'] as Map? ?? const {},
    );
    final preferenceCategories = (leaderPreferences['activity_tags'] as List? ??
            groupPreferences['categories'] as List? ??
            const [])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList();
    final dietaryPreferences = (leaderPreferences['dietary_preferences'] as List? ??
            const [])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty && value.toLowerCase() != 'none')
        .toList();
    final accessibilityPreferences =
        (leaderPreferences['accessibility_preferences'] as List? ?? const [])
            .map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList();
    final creatorBudget = leaderPreferences['max_budget'];
    final displayBudget = creatorBudget != null
        ? '₱${_formatAmount(creatorBudget)}'
        : groupPreferences['budget']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const CircleAvatar(
          backgroundColor: AppColors.orangeSoft,
          child: Icon(Icons.route_rounded, color: AppColors.orange),
        ),
        title: Text(
          trip['title']?.toString() ??
              itinerary['title']?.toString() ??
              'Shared itinerary',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.ui(15, FontWeight.w800, color: AppColors.navy),
        ),
        subtitle: Text(
          'Shared by $owner · ${trip['date_label']?.toString() ?? 'Flexible dates'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
        ),
        children: [
          _InfoLine(
            label: 'Original trip',
            value: trip['title']?.toString() ?? 'Trip',
          ),
          _InfoLine(
            label: 'Meetup',
            value: trip['meetup_full']?.toString() ?? 'Manila',
          ),
          _InfoLine(
            label: 'Tour duration',
            value:
                '${trip['duration_days'] ?? 1} ${(trip['duration_days'] ?? 1) == 1 ? 'day' : 'days'}',
          ),
          if (trip['arrival_target'] != null &&
              trip['arrival_target'].toString().isNotEmpty)
            _InfoLine(label: 'Arrival time', value: trip['arrival_target'].toString()),
          if (displayBudget != null && displayBudget.trim().isNotEmpty)
            _InfoLine(label: 'Creator budget', value: displayBudget),
          if (preferenceCategories.isNotEmpty ||
              dietaryPreferences.isNotEmpty ||
              accessibilityPreferences.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Creator preferences',
                style: AppText.ui(13, FontWeight.w800, color: AppColors.navy),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...preferenceCategories,
                ...dietaryPreferences,
                ...accessibilityPreferences,
              ].map((value) => _PreferenceChip(label: value)).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Itinerary · ${stops.length} stops',
              style: AppText.ui(13, FontWeight.w800, color: AppColors.navy),
            ),
          ),
          const SizedBox(height: 4),
          if (stops.isEmpty)
            Text(
              'No stop details available.',
              style: AppText.ui(12, FontWeight.w400, color: AppColors.muted),
            )
          else
            for (final stop in stops)
              _InfoLine(
                label: 'Day ${stop['day_number'] ?? 1}',
                value:
                    stop['name']?.toString() ??
                    stop['place_name']?.toString() ??
                    stop['title']?.toString() ??
                    'Place',
              ),
          const SizedBox(height: 12),
          if (canJoin)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: requesting || requested ? null : onRequestJoin,
                icon: requesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        requested
                            ? Icons.hourglass_top_rounded
                            : Icons.group_add_outlined,
                      ),
                label: Text(
                  requested
                      ? 'Request Sent · Waiting for Leader'
                      : 'Request to Join Original Trip',
                ),
              ),
            )
          else
            Text(
              'The original trip is no longer accepting members.',
              style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add_road_rounded),
              label: const Text('Create New Group from Itinerary'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            ),
          ),
          if (tripId.isEmpty) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

String _formatAmount(Object amount) {
  final parsed = double.tryParse(amount.toString());
  if (parsed == null) return amount.toString();
  final whole = parsed.round().toString();
  return whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

class _PreferenceChip extends StatelessWidget {
  const _PreferenceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.orangeSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: AppText.ui(10, FontWeight.w600, color: AppColors.orange),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppText.ui(12, FontWeight.w600, color: AppColors.text),
          ),
        ),
      ],
    ),
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.message, this.action, this.onTap});

  final String message;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        const Icon(Icons.route_outlined, color: AppColors.muted, size: 34),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.ui(13, FontWeight.w500, color: AppColors.muted),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}
