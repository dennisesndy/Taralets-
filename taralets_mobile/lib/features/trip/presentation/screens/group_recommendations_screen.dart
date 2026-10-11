import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/utils/activity_category_helper.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/auth_motion.dart';
import '../../../../shared/widgets/taralets_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Parsing helpers (fixes the stray quotes / braces in labels)
// ─────────────────────────────────────────────────────────────────────────────

final _edgeJunk = RegExp(r'''^[\s"'\[\]{}]+|[\s"'\[\]{}]+$''');

/// For free text (name, address, description): strips matching wrapper quotes.
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

/// For short labels (categories, tags): strips ALL leading/trailing
/// quotes, brackets and braces, e.g. `{"Exhibition Viewing"}` -> `Exhibition Viewing`.
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

/// Handles real lists, JSON arrays (`["a","b"]`), Postgres arrays
/// (`{"a","b"}`), and plain comma/semicolon/pipe separated strings.
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
  final withCommas =
      s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
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
// View-model: clean everything ONCE after fetching
// ─────────────────────────────────────────────────────────────────────────────

class _Place {
  const _Place({
    required this.id,
    required this.name,
    required this.category,
    required this.district,
    required this.address,
    required this.description,
    required this.imageUrl,
    required this.tags,
    required this.activityTags,
    required this.percent,
    required this.isNew,
    required this.searchText,
    this.costLabel,
    this.entranceLabel,
    this.rating,
    this.reviews,
    this.hours,
    this.days,
    this.dietary = const [],
    this.perks = const [],
  });

  final String id;
  final String name;
  final String category;
  final String district;
  final String address;
  final String description;
  final String imageUrl;

  /// Shown on the card: category + sub categories only.
  final List<String> tags;

  /// NOT shown as tags. Used for search only.
  final List<String> activityTags;

  final int percent;
  final bool isNew;
  final String searchText;
  final String? costLabel;
  final String? entranceLabel;
  final double? rating;
  final int? reviews;
  final String? hours;
  final String? days;
  final List<String> dietary;
  final List<String> perks;

  bool get hasDetails =>
      hours != null ||
      days != null ||
      entranceLabel != null ||
      dietary.isNotEmpty ||
      perks.isNotEmpty;

  factory _Place.from(Map<String, dynamic> raw, int index) {
    final name = _cleanText(raw['name'], 'Unnamed place');

    final rawCategory = _cleanLabel(raw['category']);
    var category = 'Other';
    if (rawCategory.isNotEmpty) {
      final normalized = _cleanLabel(normalizeActivityCategory(rawCategory));
      category = normalized.isNotEmpty ? normalized : _titleCase(rawCategory);
    }

    final subs = [
      raw['sub_category_1'],
      raw['sub_category_2'],
      raw['sub_category_3'],
    ].map((e) => _titleCase(_cleanLabel(e))).where((e) => e.isNotEmpty);

    final tags = _dedupe([if (rawCategory.isNotEmpty) category, ...subs]);
    final activityTags =
        _dedupe(_parseList(raw['activity_tags']).map(_titleCase));

    final district = _cleanText(raw['district']);
    final address = _cleanText(raw['address']);
    final description = _cleanText(raw['description']);
    final imageUrl = _cleanText(raw['image_url']);

    var score =
        (num.tryParse(_cleanText(raw['match_score'], '0')) ?? 0).toDouble();
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
    if (minCost == 0 && (maxCost == null || maxCost == 0)) costLabel = 'Free';

    final fee = _cleanText(raw['entrance_fee']);
    String? entrance;
    if (fee.isNotEmpty) {
      final n = num.tryParse(fee);
      entrance =
          n == null ? fee : (n == 0 ? 'Free entrance' : 'Entrance ${_peso(n)}');
    }

    final ratingVal = num.tryParse(_cleanText(raw['rating']));
    final rating =
        (ratingVal != null && ratingVal > 0) ? ratingVal.toDouble() : null;
    final reviews = num.tryParse(_cleanText(raw['reviews']))?.toInt();

    final open = _fmtTime(raw['open_time']);
    final close = _fmtTime(raw['close_time']);
    final hours = (open.isNotEmpty && close.isNotEmpty) ? '$open – $close' : null;
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

    return _Place(
      id: '${_cleanText(raw['master_id'], name)}_$index',
      name: name,
      category: category,
      district: district,
      address: address,
      description: description,
      imageUrl: imageUrl,
      tags: tags,
      activityTags: activityTags,
      percent: percent,
      isNew: raw['is_new'] == true,
      searchText: searchText,
      costLabel: costLabel,
      entranceLabel: entrance,
      rating: rating,
      reviews: reviews,
      hours: hours,
      days: days,
      dietary: dietary,
      perks: perks,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class GroupRecommendationsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupRecommendationsScreen({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<GroupRecommendationsScreen> createState() =>
      _GroupRecommendationsScreenState();
}

class _GroupRecommendationsScreenState
    extends ConsumerState<GroupRecommendationsScreen> {
  final _searchController = TextEditingController();

  List<_Place> _places = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendations({bool silent = false}) async {
    if (widget.groupId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Missing trip ID. Please return to your trip lobby.';
      });
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    debugPrint('FETCHING GROUP RECOMMENDATIONS: ${widget.groupId}');

    try {
      final recs = await ref
          .read(tripRepositoryProvider)
          .getGroupRecommendations(widget.groupId);

      debugPrint('GROUP RECOMMENDATIONS COUNT: ${recs.length}');

      if (!mounted) return;

      final places = [
        for (var i = 0; i < recs.length; i++) _Place.from(recs[i], i),
      ];

      setState(() {
        _places = places;
        _error = null;
        if (_selectedCategory != 'All' &&
            !places.any((p) => p.category == _selectedCategory)) {
          _selectedCategory = 'All';
        }
      });
    } on TripException catch (e) {
      debugPrint('RECOMMENDATIONS API ERROR: ${e.message}');
      if (mounted) setState(() => _error = e.message);
    } catch (e, stackTrace) {
      debugPrint('GROUP RECOMMENDATIONS ERROR: $e');
      debugPrint('$stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Unable to load recommendations. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Derived data ──────────────────────────────────────────────────────────

  /// Tabs = unique categories (with counts), alphabetical, "All" first.
  List<MapEntry<String, int>> get _categoryTabs {
    final counts = <String, int>{};
    for (final p in _places) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return [MapEntry('All', _places.length), ...sorted];
  }

  List<_Place> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _places.where((p) {
      final matchesCategory =
          _selectedCategory == 'All' || p.category == _selectedCategory;
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

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
      return _MessageState(
        icon: Icons.explore_outlined,
        title: 'No recommendations yet',
        message:
            'We couldn\'t find places that fit this group yet. Make sure members have saved their preferences, then refresh.',
        action: TextButton.icon(
          onPressed: _fetchRecommendations,
          icon: const Icon(Icons.refresh, color: AppColors.orange),
          label: Text('Refresh',
              style: AppText.ui(14, FontWeight.w800, color: AppColors.orange)),
        ),
      );
    }

    final results = _filtered;

    return Column(
      children: [
        _buildSearch(),
        _buildCategoryTabs(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${results.length} ${results.length == 1 ? 'place' : 'places'}'
                  '${_selectedCategory != 'All' ? ' in $_selectedCategory' : ''}',
                  style: AppText.ui(12, FontWeight.w700, color: AppColors.muted),
                ),
              ),
              if (_filtersActive)
                TextButton(
                  onPressed: _resetFilters,
                  child: Text('Reset',
                      style: AppText.ui(12, FontWeight.w800,
                          color: AppColors.orange)),
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
                    child: Text('Show all places',
                        style: AppText.ui(14, FontWeight.w800,
                            color: AppColors.orange)),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: () => _fetchRecommendations(silent: true),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final place = results[index];
                      return AuthReveal(
                        key: ValueKey(place.id),
                        offset: 14,
                        delay: Duration(
                            milliseconds: (index < 5 ? index : 0) * 70),
                        child: _PlaceCard(
                          place: place,
                          query: _searchQuery,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: AppText.ui(14, FontWeight.w500, color: AppColors.navy),
          decoration: InputDecoration(
            hintText: 'Search places, activities, or categories…',
            hintStyle: AppText.ui(14, FontWeight.w400, color: AppColors.muted),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.muted, size: 20),
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
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final tab = tabs[i];
          return Center(
            child: _CategoryChip(
              label: tab.key,
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
            color: selected ? AppColors.orange : AppColors.border,
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
                color: selected
                    ? Colors.white.withOpacity(0.25)
                    : AppColors.bg,
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
// Place card (tap to expand)
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceCard extends StatefulWidget {
  const _PlaceCard({required this.place, required this.query});

  final _Place place;
  final String query;

  @override
  State<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<_PlaceCard> {
  bool _expanded = false;

  /// If the search matched ONLY via an activity tag (not name / visible tags),
  /// return that activity so we can explain why the place appeared.
  String? _activityHit() {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final p = widget.place;
    final visible = p.name.toLowerCase().contains(q) ||
        p.tags.any((t) => t.toLowerCase().contains(q));
    if (visible) return null;
    for (final t in p.activityTags) {
      if (t.toLowerCase().contains(q)) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final hit = _activityHit();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image + badges ──
              Stack(
                children: [
                  _PlaceImage(url: p.imageUrl),
                  if (p.isNew)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 12, color: AppColors.navy),
                            const SizedBox(width: 4),
                            Text('Hidden Gem',
                                style: AppText.ui(11, FontWeight.w800,
                                    color: AppColors.navy)),
                          ],
                        ),
                      ),
                    ),
                  if (p.rating != null)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 15, color: AppColors.gold),
                            const SizedBox(width: 3),
                            Text(
                              p.reviews != null
                                  ? '${p.rating!.toStringAsFixed(1)} (${p.reviews})'
                                  : p.rating!.toStringAsFixed(1),
                              style: AppText.ui(12, FontWeight.w800,
                                  color: AppColors.navy),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.ui(17, FontWeight.w800,
                                    color: AppColors.navy, height: 1.25),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.district.isEmpty
                                    ? p.category
                                    : '${p.category} • ${p.district}',
                                style: AppText.ui(12.5, FontWeight.w500,
                                    color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _MatchRing(percent: p.percent),
                      ],
                    ),

                    if (hit != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.orangeSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 14, color: AppColors.orange),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Matches activity: $hit',
                                overflow: TextOverflow.ellipsis,
                                style: AppText.ui(11.5, FontWeight.w700,
                                    color: AppColors.navy),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (p.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: Text(
                          p.description,
                          maxLines: _expanded ? null : 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(13, FontWeight.w400,
                              color: AppColors.muted, height: 1.45),
                        ),
                      ),
                    ],

                    if (p.address.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: p.address,
                        maxLines: _expanded ? 3 : 1,
                      ),
                    ],
                    if (p.costLabel != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.payments_outlined,
                        text: p.costLabel!,
                        bold: true,
                      ),
                    ],

                    // Tags = category + sub categories only
                    if (p.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in p.tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                tag,
                                style: AppText.ui(11, FontWeight.w700,
                                    color: AppColors.navy),
                              ),
                            ),
                        ],
                      ),
                    ],

                    // ── Expanded details ──
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: !_expanded
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(
                                      height: 1, color: AppColors.border),
                                  const SizedBox(height: 12),
                                  if (!p.hasDetails)
                                    Text(
                                      'No additional details available.',
                                      style: AppText.ui(12, FontWeight.w500,
                                          color: AppColors.muted),
                                    ),
                                  if (p.hours != null)
                                    _InfoRow(
                                        icon: Icons.schedule_outlined,
                                        text: p.hours!),
                                  if (p.days != null) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                        icon: Icons.calendar_today_outlined,
                                        text: p.days!,
                                        maxLines: 2),
                                  ],
                                  if (p.entranceLabel != null) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                        icon: Icons
                                            .confirmation_number_outlined,
                                        text: p.entranceLabel!),
                                  ],
                                  if (p.dietary.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _InfoRow(
                                        icon: Icons.restaurant_menu_outlined,
                                        text: p.dietary.join(', '),
                                        maxLines: 2),
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
                                                horizontal: 9, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppColors.greenSoft,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.check_rounded,
                                                    size: 13,
                                                    color:
                                                        AppColors.greenText),
                                                const SizedBox(width: 4),
                                                Text(perk,
                                                    style: AppText.ui(
                                                        11, FontWeight.w700,
                                                        color: AppColors
                                                            .greenText)),
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

                    const SizedBox(height: 8),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded ? 'Show less' : 'Details',
                            style: AppText.ui(12, FontWeight.w800,
                                color: AppColors.orange),
                          ),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 250),
                            child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: AppColors.orange),
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

class _PlaceImage extends StatelessWidget {
  const _PlaceImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: 180,
      width: double.infinity,
      color: AppColors.bg,
      child: const Icon(Icons.place_outlined, size: 44, color: AppColors.muted),
    );

    if (!(url.startsWith('http://') || url.startsWith('https://'))) {
      return placeholder;
    }

    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          Image.network(
            url,
            fit: BoxFit.cover,
            frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
              opacity: (frame == null && !sync) ? 0 : 1,
              duration: const Duration(milliseconds: 350),
              child: child,
            ),
            errorBuilder: (_, __, ___) => placeholder,
          ),
        ],
      ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          height: 50,
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
              Text('$percent%',
                  style: AppText.ui(12, FontWeight.w800, color: color)),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text('Group match',
            style: AppText.ui(9, FontWeight.w600, color: AppColors.muted)),
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
            Text(title,
                textAlign: TextAlign.center,
                style: AppText.ui(17, FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.ui(13, FontWeight.w400,
                    color: AppColors.muted, height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
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
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(8),
        ),
      );

  Widget _card() => Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
      opacity: Tween(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        children: [_card(), _card()],
      ),
    );
  }
}