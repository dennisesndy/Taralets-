import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/activity_category_helper.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/auth_motion.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../itinerary/data/models/itinerary_draft_models.dart';
import '../../../itinerary/data/models/itinerary_models.dart';
import '../../../itinerary/data/itinerary_api_mapper.dart';
import '../../../itinerary/presentation/controllers/itinerary_draft_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

IconData getCategoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('church') || c.contains('religious') || c.contains('heritage'))
    return Icons.church;
  if (c.contains('restaurant') || c.contains('eatery') || c.contains('food'))
    return Icons.restaurant_menu;
  if (c.contains('cafe') || c.contains('bakery') || c.contains('dessert'))
    return Icons.local_cafe;
  if (c.contains('shopping') || c.contains('retail') || c.contains('mall'))
    return Icons.shopping_bag_outlined;
  if (c.contains('health') || c.contains('wellness') || c.contains('spa'))
    return Icons.spa_outlined;
  if (c.contains('accommodation') || c.contains('hotel'))
    return Icons.hotel_outlined;
  if (c.contains('park') || c.contains('nature')) return Icons.park_outlined;
  if (c.contains('museum') || c.contains('art')) return Icons.museum_outlined;
  if (c.contains('entertainment') || c.contains('leisure'))
    return Icons.local_play_outlined;
  return Icons.place_outlined;
}

final _edgeJunk = RegExp(r'''^[\s"'\[\]{}]+|[\s"'\[\]{}]+$''');

String _cleanText(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  var s = value.toString().trim();
  while (s.length >= 2 &&
      ((s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'")))) {
    s = s.substring(1, s.length - 1).trim();
  }
  final l = s.toLowerCase();
  if (s.isEmpty || l == 'nan' || l == 'null' || l == 'none') return fallback;
  return s;
}

String _cleanLabel(dynamic value) {
  final s = (value ?? '')
      .toString()
      .replaceAll(_edgeJunk, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final l = s.toLowerCase();
  if (l == 'nan' || l == 'null' || l == 'none') return '';
  return s;
}

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

List<String> _dedupe(Iterable<String> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final i in items) {
    if (i.isNotEmpty && seen.add(i.toLowerCase())) out.add(i);
  }
  return out;
}

List<String> _rankGroupActivities(Iterable members) {
  final support = <String, int>{};
  final firstSeen = <String, int>{};
  var sequence = 0;
  for (final member in members) {
    final activities = normalizeActivityCategories(member.activityTags);
    for (final activity in activities) {
      final key = activity.toLowerCase();
      firstSeen.putIfAbsent(key, () => sequence++);
      support[key] = (support[key] ?? 0) + 1;
    }
  }
  final ranked = support.keys.toList()
    ..sort((a, b) {
      final bySupport = (support[b] ?? 0).compareTo(support[a] ?? 0);
      return bySupport != 0
          ? bySupport
          : (firstSeen[a] ?? 0).compareTo(firstSeen[b] ?? 0);
    });
  return ranked
      .map(
        (key) => support.keys.firstWhere(
          (activity) => activity.toLowerCase() == key,
        ),
      )
      .toList();
}

List<String> _parseList(dynamic value) {
  if (value == null) return const [];
  if (value is Iterable) return value.expand<String>(_parseList).toList();

  final raw = value.toString().trim();
  if (raw.isEmpty) return const [];

  if (raw.startsWith('[')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.expand<String>(_parseList).toList();
    } catch (_) {}
  }

  final parts = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (final ch in raw.split('')) {
    if (ch == '"') {
      inQuotes = !inQuotes;
      continue;
    }
    if (!inQuotes && (ch == ',' || ch == ';' || ch == '|')) {
      parts.add(buf.toString());
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  parts.add(buf.toString());

  return _dedupe(parts.map(_cleanLabel));
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  final s = v?.toString().trim().toLowerCase();
  return s == 'true' || s == 'yes' || s == 'y' || s == '1';
}

String _peso(num n) {
  final s = n.round().toString();
  final withCommas = s.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₱$withCommas';
}

String _fmtTime(dynamic v) {
  final s = _cleanText(v);
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
  if (m == null) return s;
  var h = int.parse(m.group(1)!);
  final min = m.group(2)!;
  final suffix = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:$min $suffix';
}

// ─────────────────────────────────────────────────────────────────────────────
// View-model
// ─────────────────────────────────────────────────────────────────────────────

class _Place {
  const _Place({
    required this.id,
    required this.backendId,
    required this.name,
    required this.category,
    required this.district,
    required this.address,
    required this.description,
    required this.imageUrl,
    required this.tags,
    required this.activityTags,
    required this.activityCategories,
    required this.percent,
    required this.isNew,
    required this.searchText,
    required this.budget,
    this.costLabel,
    this.entranceLabel,
    this.rating,
    this.reviews,
    this.hours,
    this.days,
    this.dietary = const [],
    this.perks = const [],
    this.accessibilityMatchStatus = 'not_requested',
    this.activityMatch = false,
  });

  final String id;
  final String backendId;
  final String name;
  final String category;
  final String district;
  final String address;
  final String description;
  final String imageUrl;
  final List<String> tags;
  final List<String> activityTags;
  final List<String> activityCategories;
  final int percent;
  final bool isNew;
  final String searchText;
  final int budget;

  final String? costLabel;
  final String? entranceLabel;
  final double? rating;
  final int? reviews;
  final String? hours;
  final String? days;
  final List<String> dietary;
  final List<String> perks;
  final String accessibilityMatchStatus;
  final bool activityMatch;

  bool get hasDetails =>
      hours != null ||
      days != null ||
      entranceLabel != null ||
      dietary.isNotEmpty ||
      perks.isNotEmpty;

  ItineraryCandidate toCandidate() => ItineraryCandidate(
    id: id,
    backendId: backendId,
    name: name,
    category: category,
    area: district,
    address: address,
    description: description,
    imageUrl: imageUrl,
    icon: itineraryIconForCategory(category),
    budget: budget,
    groupScore: percent / 100,
    activityTags: activityTags,
    dietaryTags: dietary,
    accessibilityTags: perks,
  );

  factory _Place.from(
    Map<String, dynamic> raw,
    int index, {
    List<String> selectedActivities = const [],
  }) {
    final name = _cleanText(raw['name'], 'Unnamed place');
    final rawCategory = _cleanLabel(raw['category']);
    var category = 'Other';
    if (rawCategory.isNotEmpty) {
      final normalized = _cleanLabel(normalizeActivityCategory(rawCategory));
      category = normalized.isNotEmpty ? normalized : _titleCase(rawCategory);
    }
    final backendMatchedCategories = _dedupe(
      _parseList(raw['matched_activity_categories']).map((value) {
        final normalized = _cleanLabel(normalizeActivityCategory(value));
        return normalized.isNotEmpty ? normalized : _titleCase(value);
      }),
    );

    final subs = _dedupe(
      [
        raw['sub_category_1'],
        raw['sub_category_2'],
        raw['sub_category_3'],
      ].expand(_parseList).map(_titleCase).where((e) => e.isNotEmpty),
    );
    final activityTags = _dedupe(
      _parseList(raw['activity_tags']).map(_titleCase),
    );
    final placeActivityCategories = normalizeActivityCategories([
      if (rawCategory.isNotEmpty) rawCategory,
      ...subs,
      ...activityTags,
    ]);
    final placeCategoryKeys = placeActivityCategories
        .map((value) => value.toLowerCase())
        .toSet();
    final locallyMatchedCategories = selectedActivities
        .where(
          (value) => placeCategoryKeys.contains(
            normalizeActivityCategory(value).toLowerCase(),
          ),
        )
        .toList();
    final matchedCategories = selectedActivities.isEmpty
        ? backendMatchedCategories
        : locallyMatchedCategories;
    if (matchedCategories.isNotEmpty) category = matchedCategories.first;
    final activityCategories = selectedActivities.isEmpty
        ? (matchedCategories.isEmpty ? [category] : matchedCategories)
        : matchedCategories;

    final tags = _dedupe([category, ...matchedCategories, ...subs]);
    final district = _cleanText(raw['district']);
    final address = _cleanText(raw['address']);
    final description = _cleanText(raw['description']);
    final imageUrl = _cleanText(raw['image_url']);

    var score = (num.tryParse(_cleanText(raw['match_score'], '0')) ?? 0)
        .toDouble();
    if (score <= 1) score *= 100;
    final percent = score.round().clamp(0, 100).toInt();

    final minCost = num.tryParse(_cleanText(raw['min_cost']));
    final maxCost = num.tryParse(_cleanText(raw['max_cost']));
    String? costLabel;
    if (minCost != null && maxCost != null) {
      costLabel = minCost == maxCost
          ? _peso(minCost)
          : '${_peso(minCost)} – ${_peso(maxCost)}';
    } else if (minCost != null) {
      costLabel = 'From ${_peso(minCost)}';
    } else if (maxCost != null) {
      costLabel = 'Up to ${_peso(maxCost)}';
    }
    if (minCost == 0 && (maxCost == null || maxCost == 0))
      costLabel = 'Free / Not specified';

    final fee = _cleanText(raw['entrance_fee']);
    final feeValue = num.tryParse(fee);
    String? entrance;
    if (fee.isNotEmpty) {
      entrance = feeValue == null
          ? fee
          : (feeValue == 0 ? 'Free entrance' : 'Entrance ${_peso(feeValue)}');
    }

    final baseCost = (minCost != null && minCost > 0)
        ? minCost
        : (maxCost ?? 0);
    final budget = (baseCost + (feeValue ?? 0)).round();

    final ratingVal = num.tryParse(_cleanText(raw['rating']));
    final rating = (ratingVal != null && ratingVal > 0)
        ? ratingVal.toDouble()
        : null;
    final reviews = num.tryParse(_cleanText(raw['reviews']))?.toInt();

    final open = _fmtTime(raw['open_time']);
    final close = _fmtTime(raw['close_time']);
    final hours = (open.isNotEmpty && close.isNotEmpty)
        ? '$open – $close'
        : null;
    final daysList = _parseList(raw['days_open']);
    final days = daysList.isEmpty ? null : daysList.join(', ');

    final dietary = _dedupe(_parseList(raw['dietary_options']).map(_titleCase));
    final perks = [
      if (_asBool(raw['pet_friendly'])) 'Pet friendly',
      if (_asBool(raw['wheelchair_accessible'])) 'Wheelchair accessible',
      if (_asBool(raw['good_for_children'])) 'Good for kids',
    ];

    final searchText = [
      name,
      rawCategory,
      category,
      ...subs,
      ...activityTags,
      district,
      address,
      description,
    ].join(' ').toLowerCase();

    final masterId = _cleanText(raw['master_id'], '');
    final rawId = _cleanText(raw['id'], '');
    final backendId = masterId.isNotEmpty ? masterId : rawId;
    final displayId = backendId.isNotEmpty ? backendId : name;

    return _Place(
      id: '${displayId}_$index',
      backendId: backendId,
      name: name,
      category: category,
      district: district,
      address: address,
      description: description,
      imageUrl: imageUrl,
      tags: tags,
      activityTags: activityTags,
      activityCategories: activityCategories,
      percent: percent,
      isNew: raw['is_new'] == true,
      searchText: searchText,
      budget: budget,
      costLabel: costLabel ?? 'Free / Not specified',
      entranceLabel: entrance,
      rating: rating,
      reviews: reviews,
      hours: hours,
      days: days,
      dietary: dietary,
      perks: perks,
      accessibilityMatchStatus:
          raw['accessibility_match_status']?.toString() ?? 'unknown',
      activityMatch: raw['activity_match'] == true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class GroupRecommendationsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupRecommendationsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupRecommendationsScreen> createState() =>
      _GroupRecommendationsScreenState();
}

class _GroupRecommendationsScreenState
    extends ConsumerState<GroupRecommendationsScreen> {
  final _searchController = TextEditingController();
  final _categoryScrollController = ScrollController();

  List<_Place> _places = [];
  List<String> _selectedGroupActivities = const [];
  int _averagePlacesPerDay = 3;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  late final ItineraryDraftController _draft;

  // Pagination State
  int _currentRadius = 3000;
  int _currentOffset = 0;
  final int _limit = 30;
  bool _hasMore = true;
  Timer? _voteRefreshTimer;
  bool _refreshingVoteState = false;
  bool _votingScreenOpen = false;
  bool _loadingMore = false;

  int? get _nextRadius {
    const radiusSteps = [3000, 5000, 8000, 10000];
    for (final radius in radiusSteps) {
      if (radius > _currentRadius) return radius;
    }
    return null;
  }

  String _radiusLabel(int meters) =>
      meters % 1000 == 0 ? '${meters ~/ 1000} km' : '${meters} m';

  String _placeKey(_Place place) =>
      place.backendId.isNotEmpty ? place.backendId : place.id;

  Future<void> _expandSearchRadius() async {
    final nextRadius = _nextRadius;
    if (nextRadius == null || _loadingMore) return;
    setState(() {
      _currentRadius = nextRadius;
      _currentOffset = 0;
      _hasMore = true;
    });
    await _fetchRecommendations(isLoadMore: true);
  }

  @override
  void initState() {
    super.initState();
    _draft = ItineraryDraftController(
      tripId: widget.groupId,
      members: const [],
    );
    _loadInitialRecommendations();
    _voteRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshGroupVoteState(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    _voteRefreshTimer?.cancel();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _refreshGroupVoteState() async {
    if (_refreshingVoteState ||
        widget.groupId.trim().isEmpty ||
        _votingScreenOpen ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _refreshingVoteState = true;
    try {
      final state = await ref
          .read(tripRepositoryProvider)
          .getItinerarySelections(widget.groupId);
      if (!mounted) return;
      final selections = (state['selections'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final members = (state['members'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _draft.hydrateGroupVotes(
        selections: selections,
        members: members,
        candidateFromApi: itineraryCandidateFromSelection,
      );
      setState(() {});
    } on TripException {
      // Keep the current recommendation list visible if the vote refresh fails.
    } finally {
      _refreshingVoteState = false;
    }
  }

  Future<void> _addToItinerary(_Place place) async {
    if (_draft.isCurrentUserAdded(place.backendId)) return;
    HapticFeedback.selectionClick();
    _draft.add(place.toCandidate());
    setState(() {});
    try {
      await ref.read(tripRepositoryProvider).addItinerarySelections(
        widget.groupId,
        [place.backendId],
      );
    } on TripException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _loadInitialRecommendations() async {
    await _loadGroupContext();
    if (mounted) await _fetchRecommendations();
  }

  Future<void> _reviewSelected() async {
    if (_draft.selected.isEmpty) return;

    if (_draft.memberCount == 0) {
      await _loadGroupContext();
      if (!mounted) return;
    }

    if (_draft.memberCount == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not load the group members. Please try again.',
            ),
          ),
        );
      return;
    }

    try {
      final placeIds = _draft.selected
          .map((candidate) => candidate.backendId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      await ref
          .read(tripRepositoryProvider)
          .addItinerarySelections(widget.groupId, placeIds);
    } on TripException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }

    if (!mounted) return;

    setState(() => _votingScreenOpen = true);
    try {
      await context.push(
        AppRoutes.selectedPlaces,
        extra: {'draft': _draft, 'tripId': widget.groupId},
      );
    } finally {
      if (mounted) setState(() => _votingScreenOpen = false);
    }
  }

  Future<void> _loadGroupContext() async {
    if (widget.groupId.trim().isEmpty) return;
    try {
      final tripFuture = ref
          .read(tripRepositoryProvider)
          .getTrip(widget.groupId);
      final meFuture = ref.read(currentUserProvider.future);
      final trip = await tripFuture;
      _selectedGroupActivities = _rankGroupActivities(trip.members);
      final placeTargets = trip.members
          .map((member) => member.desiredPlacesPerDay)
          .whereType<int>()
          .where((target) => target > 0)
          .toList();
      _averagePlacesPerDay = placeTargets.isEmpty
          ? 3
          : (placeTargets.reduce((a, b) => a + b) / placeTargets.length + 0.5)
                .floor();
      final me = await meFuture;

      final members = <ItineraryMember>[];
      ItineraryMember? currentMember;

      for (final member in trip.members) {
        final displayName = member.name.trim().isNotEmpty
            ? member.name
            : member.username.trim().isNotEmpty
            ? member.username
            : 'Member';

        final matchesCurrentUser =
            member.id == me.id ||
            (member.username.isNotEmpty &&
                member.username.toLowerCase() == me.username.toLowerCase()) ||
            (member.name.toLowerCase() == me.fullName.toLowerCase());
        final isCurrentUser = matchesCurrentUser && currentMember == null;

        final itineraryMember = ItineraryMember(
          name: displayName,
          isCurrentUser: isCurrentUser,
        );
        members.add(itineraryMember);
        if (isCurrentUser) currentMember = itineraryMember;
      }

      if (currentMember == null) {
        final meName = me.fullName.trim().isNotEmpty
            ? me.fullName
            : me.username.trim().isNotEmpty
            ? me.username
            : 'You';
        currentMember = ItineraryMember(name: meName, isCurrentUser: true);
        members.add(currentMember);
      }

      if (!mounted) return;
      _draft.updateGroupMembers(
        members: members,
        currentUserName: currentMember.name,
      );
      final voteState = await ref
          .read(tripRepositoryProvider)
          .getItinerarySelections(widget.groupId);
      if (!mounted) return;
      final selections = (voteState['selections'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final voteMembers = (voteState['members'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _draft.hydrateGroupVotes(
        selections: selections,
        members: voteMembers,
        candidateFromApi: itineraryCandidateFromSelection,
      );
    } catch (e) {
      debugPrint('GROUP CONTEXT ERROR: $e');
    }
  }

  Future<void> _fetchRecommendations({bool isLoadMore = false}) async {
    if (widget.groupId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Missing trip ID. Please return to your trip lobby.';
      });
      return;
    }

    if (isLoadMore) {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _currentOffset = 0;
        _hasMore = true;
      });
    }

    try {
      final existingKeys = isLoadMore
          ? _places.map(_placeKey).toSet()
          : <String>{};
      var addedPlaces = <_Place>[];
      var recs = <Map<String, dynamic>>[];

      do {
        recs = await ref
            .read(tripRepositoryProvider)
            .getGroupRecommendations(
              widget.groupId,
              radius: _currentRadius,
              limit: _limit,
              offset: _currentOffset,
            );
        if (!mounted) return;

        _currentOffset += recs.length;
        if (recs.isNotEmpty) {
          final rankedActivities = _dedupe(
            _parseList(recs.first['_group_activity_preferences']).map((value) {
              final normalized = _cleanLabel(normalizeActivityCategory(value));
              return normalized.isNotEmpty ? normalized : _titleCase(value);
            }),
          );
          if (rankedActivities.isNotEmpty) {
            _selectedGroupActivities = rankedActivities;
          }
        }

        final newPlaces = [
          for (var i = 0; i < recs.length; i++)
            _Place.from(
              recs[i],
              _currentOffset - recs.length + i,
              selectedActivities: _selectedGroupActivities,
            ),
        ];
        final activityFilteredPlaces = _selectedGroupActivities.isEmpty
            ? newPlaces
            : newPlaces
                  .where((place) => place.activityCategories.isNotEmpty)
                  .toList();
        addedPlaces = activityFilteredPlaces
            .where((place) => existingKeys.add(_placeKey(place)))
            .toList();
        _hasMore = recs.length == _limit;
      } while (isLoadMore && addedPlaces.isEmpty && _hasMore);

      setState(() {
        if (isLoadMore) {
          _places.addAll(addedPlaces);
        } else {
          _places = addedPlaces;
        }

        _error = null;

        if (_selectedCategory != 'All' &&
            !_places.any(
              (p) => p.activityCategories.contains(_selectedCategory),
            )) {
          _selectedCategory = 'All';
        }
      });
    } on TripException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = 'Unable to load recommendations. Please try again.',
        );
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
    }
  }

  List<MapEntry<String, int>> get _categoryTabs {
    final counts = <String, int>{};
    for (final p in _places) {
      for (final category in p.activityCategories.toSet()) {
        final displayCategory = normalizeActivityCategory(category);
        counts[displayCategory] = (counts[displayCategory] ?? 0) + 1;
      }
    }
    final ordered = <String>[
      ..._selectedGroupActivities,
      ...counts.keys.where(
        (category) => !_selectedGroupActivities.any(
          (selected) => selected.toLowerCase() == category.toLowerCase(),
        ),
      ),
    ];
    final sorted = ordered
        .map((category) => MapEntry(category, counts[category] ?? 0))
        .toList();
    return [MapEntry('All', _places.length), ...sorted];
  }

  List<_Place> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _places.where((p) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          p.activityCategories.contains(_selectedCategory);
      final matchesSearch = q.isEmpty || p.searchText.contains(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  bool get _filtersActive =>
      _selectedCategory != 'All' || _searchQuery.trim().isNotEmpty;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _selectedCategory = 'All';
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Group Recommendations',
          style: AppText.ui(17, FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh recommendations',
            onPressed: _loading ? null : () => _fetchRecommendations(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _draft.selected.isEmpty
          ? null
          : _ReviewSelectedBar(
              count: _draft.currentUserAddedCount,
              onReview: _reviewSelected,
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _SkeletonList();

    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load places',
        message: _error!,
        action: SizedBox(
          width: 200,
          child: TaraletsButton.orange(
            label: 'Try Again',
            isLoading: false,
            onPressed: _fetchRecommendations,
          ),
        ),
      );
    }

    if (_places.isEmpty) {
      final nextRadius = _nextRadius;
      return _MessageState(
        icon: Icons.explore_outlined,
        title: 'No recommendations yet',
        message:
            'We couldn\'t find places within ${_radiusLabel(_currentRadius)}. Try a wider search radius or refresh.',
        action: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _fetchRecommendations,
              icon: const Icon(Icons.refresh, color: AppColors.orange),
              label: Text(
                'Refresh',
                style: AppText.ui(14, FontWeight.w800, color: AppColors.orange),
              ),
            ),
            if (_hasMore)
              TextButton.icon(
                onPressed: () => _fetchRecommendations(isLoadMore: true),
                icon: const Icon(Icons.expand_more, color: AppColors.orange),
                label: Text(
                  'Load More Places',
                  style: AppText.ui(
                    14,
                    FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
              ),
            if (nextRadius != null)
              TextButton.icon(
                onPressed: _expandSearchRadius,
                icon: const Icon(Icons.radar, color: AppColors.orange),
                label: Text(
                  'Expand to ${_radiusLabel(nextRadius)}',
                  style: AppText.ui(
                    14,
                    FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final results = _filtered;

    return Column(
      children: [
        _buildSearch(),
        _buildCategoryTabs(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
          child: Row(
            children: [
              const Icon(
                Icons.near_me_outlined,
                size: 15,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Nearby places are prioritized and grouped to fit your group’s pace of about $_averagePlacesPerDay places per day.',
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${results.length} ${results.length == 1 ? 'place' : 'places'}${_selectedCategory != 'All' ? ' in $_selectedCategory' : ''}',
                  style: AppText.ui(
                    12,
                    FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
              Text(
                'Within ${_radiusLabel(_currentRadius)}',
                style: AppText.ui(11, FontWeight.w700, color: AppColors.muted),
              ),
              if (_filtersActive)
                TextButton(
                  onPressed: _resetFilters,
                  child: Text(
                    'Reset',
                    style: AppText.ui(
                      12,
                      FontWeight.w800,
                      color: AppColors.orange,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? _MessageState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No matching places',
                  message: 'Try another category or search term.',
                  action: TextButton(
                    onPressed: _resetFilters,
                    child: Text(
                      'Show all places',
                      style: AppText.ui(
                        14,
                        FontWeight.w800,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: () => _fetchRecommendations(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount:
                        results.length +
                        ((_hasMore || _nextRadius != null) && !_filtersActive
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index == results.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: _loadingMore
                                ? const CircularProgressIndicator(
                                    color: AppColors.orange,
                                  )
                                : _hasMore
                                ? TaraletsButton.orange(
                                    small: true,
                                    full: false,
                                    label: 'Load More Places',
                                    onPressed: () =>
                                        _fetchRecommendations(isLoadMore: true),
                                  )
                                : _nextRadius != null
                                ? TaraletsButton.orange(
                                    small: true,
                                    full: false,
                                    label:
                                        'Expand search to ${_radiusLabel(_nextRadius!)}',
                                    onPressed: _expandSearchRadius,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      }

                      final place = results[index];
                      return AuthReveal(
                        key: ValueKey(place.id),
                        offset: 14,
                        delay: Duration(
                          milliseconds: (index < 5 ? index : 0) * 70,
                        ),
                        child: _PlaceCard(
                          place: place,
                          query: _searchQuery,
                          added: _draft.isCurrentUserAdded(place.backendId),
                          onAdd: () => _addToItinerary(place),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: AppText.ui(14, FontWeight.w500, color: AppColors.navy),
          decoration: InputDecoration(
            hintText: 'Search places, activities, or categories…',
            hintStyle: AppText.ui(14, FontWeight.w400, color: AppColors.muted),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.muted,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.muted,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final tabs = _categoryTabs;
    return SizedBox(
      height: 54,
      child: Scrollbar(
        controller: _categoryScrollController,
        thumbVisibility: true,
        thickness: 3,
        radius: const Radius.circular(99),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(
            context,
          ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
          child: ListView.separated(
            controller: _categoryScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            itemCount: tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final tab = tabs[i];
              return Center(
                child: _CategoryChip(
                  label: tab.key == 'All'
                      ? tab.key
                      : normalizeActivityCategory(tab.key),
                  count: tab.value,
                  selected: _selectedCategory == tab.key,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = tab.key);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category chip
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? AppColors.orange : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.ui(
                13,
                FontWeight.w700,
                color: selected ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.25) : AppColors.bg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$count',
                style: AppText.ui(
                  11,
                  FontWeight.w800,
                  color: selected ? Colors.white : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Place Card (Styled like Discover Screen)
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceCard extends StatefulWidget {
  const _PlaceCard({
    required this.place,
    required this.query,
    required this.added,
    required this.onAdd,
  });

  final _Place place;
  final String query;
  final bool added;
  final VoidCallback onAdd;

  @override
  State<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<_PlaceCard> {
  bool _expanded = false;

  String? _activityHit() {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final p = widget.place;
    final visible =
        p.name.toLowerCase().contains(q) ||
        p.tags.any((t) => t.toLowerCase().contains(q));
    if (visible) return null;
    for (final t in p.activityTags) {
      if (t.toLowerCase().contains(q)) return t;
    }
    return null;
  }

  Widget _buildImageFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.orange.withOpacity(0.15),
            AppColors.orange.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withOpacity(0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              getCategoryIcon(widget.place.category),
              size: 36,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            normalizeActivityCategory(widget.place.category),
            style: AppText.ui(
              13,
              FontWeight.w700,
              color: AppColors.orange.withOpacity(0.8),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final hit = _activityHit();
    final bool hasImage =
        p.imageUrl.isNotEmpty && p.imageUrl.toLowerCase() != 'nan';

    // Alisin ang pangkalahatang kategorya sa tag list para maiwasan ang redundancy sa UI
    final List<String> subCats = p.tags
        .where((t) => t.toLowerCase() != p.category.toLowerCase())
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Image Header ──
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: hasImage
                          ? Image.network(
                              p.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildImageFallback(),
                            )
                          : _buildImageFallback(),
                    ),
                  ),
                  if (p.isNew)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 12,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hidden Gem',
                              style: AppText.ui(
                                11,
                                FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Ratings Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: AppText.ui(
                              18,
                              FontWeight.w800,
                              color: AppColors.navy,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (p.rating != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                p.reviews != null
                                    ? '${p.rating!.toStringAsFixed(1)}'
                                    : p.rating!.toStringAsFixed(1),
                                style: AppText.ui(
                                  14,
                                  FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Category and Price Row
                    Row(
                      children: [
                        Icon(
                          getCategoryIcon(p.category),
                          size: 14,
                          color: AppColors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          normalizeActivityCategory(p.category),
                          style: AppText.ui(
                            13,
                            FontWeight.w600,
                            color: AppColors.orange,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "•",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Icon(
                          Icons.payments_outlined,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            p.costLabel ?? 'Free / Not specified',
                            style: AppText.ui(
                              13,
                              FontWeight.w500,
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (hit != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.orangeSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: AppColors.orange,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Matches activity: $hit',
                                overflow: TextOverflow.ellipsis,
                                style: AppText.ui(
                                  11.5,
                                  FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (p.accessibilityMatchStatus != 'not_requested') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: p.accessibilityMatchStatus == 'verified'
                              ? Colors.green.shade50
                              : const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          p.accessibilityMatchStatus == 'verified'
                              ? 'Accessibility verified for selected group needs'
                              : p.activityMatch
                              ? 'Activity match — accessibility not verified'
                              : 'Accessibility not verified for selected group needs',
                          style: AppText.ui(
                            11.5,
                            FontWeight.w700,
                            color: p.accessibilityMatchStatus == 'verified'
                                ? Colors.green.shade800
                                : AppColors.navy,
                          ),
                        ),
                      ),
                    ],

                    // Address Row
                    if (p.address.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.address,
                              style: AppText.ui(
                                13,
                                FontWeight.w400,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: _expanded ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Sub-categories / Tags
                    if (subCats.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: subCats
                            .map(
                              (s) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F2F5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s,
                                  style: AppText.ui(
                                    11,
                                    FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Group Match Ring & Action Button Row
                    Row(
                      children: [
                        _MatchRing(percent: p.percent),
                        const SizedBox(width: 16),
                        Expanded(
                          child: widget.added
                              ? const _AddedToItineraryBanner()
                              : TaraletsButton.orange(
                                  small: true,
                                  label: 'Add to Itinerary',
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  onPressed: widget.onAdd,
                                ),
                        ),
                      ],
                    ),

                    // ── Expanded details ──
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: !_expanded
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                  const SizedBox(height: 12),

                                  if (p.description.isNotEmpty) ...[
                                    Text(
                                      p.description,
                                      style: AppText.ui(
                                        13,
                                        FontWeight.w400,
                                        color: AppColors.muted,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  if (!p.hasDetails && p.description.isEmpty)
                                    Text(
                                      'No additional details available.',
                                      style: AppText.ui(
                                        12,
                                        FontWeight.w500,
                                        color: AppColors.muted,
                                      ),
                                    ),

                                  if (p.hours != null)
                                    _InfoRow(
                                      icon: Icons.schedule_outlined,
                                      text: p.hours!,
                                    ),
                                  if (p.days != null) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      icon: Icons.calendar_today_outlined,
                                      text: p.days!,
                                      maxLines: 2,
                                    ),
                                  ],
                                  if (p.entranceLabel != null) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      icon: Icons.confirmation_number_outlined,
                                      text: p.entranceLabel!,
                                    ),
                                  ],
                                  if (p.dietary.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                      icon: Icons.restaurant_menu_outlined,
                                      text: p.dietary.join(', '),
                                      maxLines: 2,
                                    ),
                                  ],

                                  if (p.perks.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final perk in p.perks)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.greenSoft,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.check_rounded,
                                                  size: 13,
                                                  color: AppColors.greenText,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  perk,
                                                  style: AppText.ui(
                                                    11,
                                                    FontWeight.w700,
                                                    color: AppColors.greenText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),

                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded ? 'Show less' : 'Details',
                            style: AppText.ui(
                              12,
                              FontWeight.w800,
                              color: AppColors.orange,
                            ),
                          ),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 250),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
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

class _AddedToItineraryBanner extends StatelessWidget {
  const _AddedToItineraryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: AppColors.greenText,
          ),
          const SizedBox(width: 6),
          Text(
            'Added to itinerary',
            style: AppText.ui(12, FontWeight.w800, color: AppColors.greenText),
          ),
        ],
      ),
    );
  }
}

class _ReviewSelectedBar extends StatelessWidget {
  const _ReviewSelectedBar({required this.count, required this.onReview});
  final int count;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.playlist_add_check_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your picks: $count ${count == 1 ? 'place' : 'places'}',
                    style: AppText.ui(
                      12.5,
                      FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Review and vote with the group',
                    style: AppText.ui(
                      10.5,
                      FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 40,
              child: TaraletsButton.orange(
                small: true,
                full: false,
                label: 'Review',
                icon: const Icon(
                  Icons.how_to_vote_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                onPressed: onReview,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.maxLines = 1,
    this.bold = false,
  });
  final IconData icon;
  final String text;
  final int maxLines;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.orange),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(
              12.5,
              bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? AppColors.navy : AppColors.muted,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchRing extends StatelessWidget {
  const _MatchRing({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    final high = percent >= 80;
    final color = high ? AppColors.greenText : AppColors.orange;
    final track = high ? AppColors.greenSoft : AppColors.orangeSoft;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: percent / 100),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: v,
                    strokeWidth: 4.5,
                    backgroundColor: track,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: AppText.ui(11, FontWeight.w900, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Group\nmatch',
          style: AppText.ui(
            9,
            FontWeight.w700,
            color: AppColors.muted,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// States
// ─────────────────────────────────────────────────────────────────────────────

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.orangeSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.orange),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.ui(17, FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.ui(
                13,
                FontWeight.w400,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFE7EBF2),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  Widget _card() => Container(
    margin: const EdgeInsets.only(bottom: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 124,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F3F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const Center(
            child: Icon(
              Icons.place_outlined,
              size: 34,
              color: Color(0xFFCAD2E0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(190, 18),
              const SizedBox(height: 10),
              _bar(120, 12),
              const SizedBox(height: 14),
              _bar(double.infinity, 12),
              const SizedBox(height: 8),
              _bar(240, 12),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 0.45,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        children: [
          Row(
            children: [
              const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(AppColors.orange),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Finding places for your group…',
                style: AppText.ui(13, FontWeight.w700, color: AppColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(),
          _card(),
        ],
      ),
    );
  }
}
