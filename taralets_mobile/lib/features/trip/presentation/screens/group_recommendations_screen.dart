
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../repositories/trip_repository.dart';

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
  List<Map<String, dynamic>> _allRecommendations = [];

  String _selectedCategory = 'All';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    if (widget.groupId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing trip ID. Please return to your trip lobby.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final recommendations = await ref
          .read(tripRepositoryProvider)
          .getGroupRecommendations(widget.groupId);

      if (!mounted) return;

      setState(() {
        _allRecommendations = recommendations;
      });
    } on TripException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load recommendations. Please try again.';
      });

      debugPrint('Group recommendations error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .where((item) => item != null)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }

    return [];
  }

  List<String> get _categories {
    final values = <String>{};

    for (final place in _allRecommendations) {
      final category = (place['category'] ?? '').toString().trim();

      if (category.isNotEmpty) {
        values.add(category);
      }

      values.addAll(_stringList(place['activity_tags']));
    }

    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ['All', ...sorted];
  }

  List<Map<String, dynamic>> get _filteredRecommendations {
    if (_selectedCategory == 'All') {
      return _allRecommendations;
    }

    final target = _selectedCategory.toLowerCase();

    return _allRecommendations.where((place) {
      final category = (place['category'] ?? '')
          .toString()
          .toLowerCase();

      final tags = _stringList(place['activity_tags'])
          .map((tag) => tag.toLowerCase())
          .toList();

      return category == target || tags.contains(target);
    }).toList();
  }

  String _text(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;

    final result = value.toString().trim();

    if (result.isEmpty || result.toLowerCase() == 'nan') {
      return fallback;
    }

    return result;
  }

  Widget _buildImage(Map<String, dynamic> place) {
    final imageUrl = _text(place['image_url']);

    if (imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }

    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 170,
      width: double.infinity,
      color: AppColors.bg,
      child: Icon(
        Icons.place_outlined,
        size: 48,
        color: AppColors.muted,
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final name = _text(place['name'], 'Unnamed place');
    final category = _text(place['category'], 'Place');
    final district = _text(place['district']);
    final address = _text(place['address']);
    final description = _text(place['description']);

    final tags = _stringList(place['activity_tags']);

    final score =
        (num.tryParse('${place['match_score'] ?? 0}') ?? 0)
            .toDouble();

    final percentage = (score * 100).round().clamp(0, 100);

    final minCost = num.tryParse('${place['min_cost']}');
    final maxCost = num.tryParse('${place['max_cost']}');

    String? costLabel;

    if (minCost != null && maxCost != null) {
      costLabel =
          '₱${minCost.round()} - ₱${maxCost.round()}';
    } else if (minCost != null) {
      costLabel = 'From ₱${minCost.round()}';
    } else if (maxCost != null) {
      costLabel = 'Up to ₱${maxCost.round()}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _buildImage(place),
              if (place['is_new'] == true)
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Hidden Gem',
                      style: AppText.ui(
                        11,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: AppText.ui(
                          17,
                          FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: percentage >= 80
                                ? AppColors.greenSoft
                                : AppColors.orangeSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$percentage%',
                            style: AppText.ui(
                              13,
                              FontWeight.w800,
                              color: percentage >= 80
                                  ? AppColors.greenText
                                  : AppColors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Group Match',
                          style: AppText.ui(
                            9,
                            FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  district.isEmpty
                      ? category
                      : '$category • $district',
                  style: AppText.ui(
                    12,
                    FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(
                      12,
                      FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          address,
                          style: AppText.ui(
                            11,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (costLabel != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 16,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        costLabel,
                        style: AppText.ui(
                          12,
                          FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in tags.take(4))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tag,
                            style: AppText.ui(
                              10,
                              FontWeight.w600,
                              color: AppColors.navy,
                            ),
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
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.ui(
                17,
                FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.ui(
                13,
                FontWeight.w400,
                color: AppColors.muted,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = _filteredRecommendations;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(
          'Group Recommendations',
          style: AppText.ui(
            17,
            FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh recommendations',
            onPressed: _loading ? null : _fetchRecommendations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load places',
                  message: _error!,
                  action: ElevatedButton.icon(
                    onPressed: _fetchRecommendations,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                )
              : _allRecommendations.isEmpty
                  ? _buildMessage(
                      icon: Icons.explore_outlined,
                      title: 'No recommendations yet',
                      message:
                          'The backend did not return any places for this group. Check the saved member preferences and available place data.',
                      action: OutlinedButton.icon(
                        onPressed: _fetchRecommendations,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 58,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            children: [
                              for (final category in _categories)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(category),
                                    selected:
                                        _selectedCategory == category,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedCategory = category;
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: recommendations.isEmpty
                              ? _buildMessage(
                                  icon: Icons.filter_alt_off_outlined,
                                  title: 'No matching places',
                                  message:
                                      'Try selecting another category or All.',
                                  action: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedCategory = 'All';
                                      });
                                    },
                                    child: const Text('Show All Places'),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    24,
                                  ),
                                  itemCount: recommendations.length,
                                  itemBuilder: (context, index) {
                                    return _buildPlaceCard(
                                      recommendations[index],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
    );
  }
}
