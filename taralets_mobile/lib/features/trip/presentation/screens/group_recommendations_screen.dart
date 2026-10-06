import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/taralets_button.dart';

/// Screen displaying recommended places calculated from the group consensus match.
class GroupRecommendationsScreen extends StatefulWidget {
  const GroupRecommendationsScreen({super.key});

  @override
  State<GroupRecommendationsScreen> createState() =>
      _GroupRecommendationsScreenState();
}

class _GroupRecommendationsScreenState
    extends State<GroupRecommendationsScreen> {
  String _selectedCategory = 'All';
  final Set<String> _selectedPlaceIds = {};

  static const _places = [
    (
      id: 'p1',
      name: 'Intramuros Heritage Walking Tour',
      category: 'Heritage',
      rating: '4.9 ★',
      matchScore: '98%',
      price: '₱450 / person',
      dietaryNote: 'Halal-friendly food stops nearby',
      bgColor: Color(0xFFE2E8F0),
    ),
    (
      id: 'p2',
      name: 'Barbara\'s Heritage Restaurant',
      category: 'Halal Food',
      rating: '4.7 ★',
      matchScore: '96%',
      price: '₱500 – ₱700 / person',
      dietaryNote: 'Halal Certified & Vegetarian options',
      bgColor: Color(0xFFFEF3C7),
    ),
    (
      id: 'p3',
      name: 'Escolta Heritage Cafe',
      category: 'Cafés',
      rating: '4.8 ★',
      matchScore: '93%',
      price: '₱200 – ₱350 / person',
      dietaryNote: 'Vegetarian snacks & specialty coffee',
      bgColor: Color(0xFFFFEDD5),
    ),
  ];

  BoxDecoration _card({Border? border}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      );

  Widget _pill(
    String t,
    Color bg,
    Color fg, {
    double size = 11,
    FontWeight w = FontWeight.w600,
    EdgeInsets? pad,
  }) =>
      Container(
        padding: pad ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          t,
          style: AppText.ui(size, w, color: fg),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final filteredPlaces = _selectedCategory == 'All'
        ? _places
        : _places.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BackButtonTile(
                          onTap: () => context.pop(),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group Recommendations',
                              style: AppText.ui(
                                18,
                                FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              '95% Group Consensus Match',
                              style: AppText.ui(
                                12,
                                FontWeight.w400,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Heritage', 'Halal Food', 'Cafés']
                            .map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() => _selectedCategory = cat);
                              },
                              selectedColor: AppColors.orangeSoft,
                              checkmarkColor: AppColors.orange,
                              labelStyle: AppText.ui(
                                12,
                                FontWeight.w700,
                                color: isSelected
                                    ? AppColors.orange
                                    : AppColors.navy,
                              ),
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.orange
                                      : AppColors.border,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recommendation cards
                    for (final place in filteredPlaces) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: _card(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 100,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: place.bgColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _pill(
                                    '${place.matchScore} Match',
                                    AppColors.greenSoft,
                                    AppColors.greenText,
                                    w: FontWeight.w800,
                                  ),
                                  _pill(
                                    place.rating,
                                    Colors.white,
                                    AppColors.navy,
                                    w: FontWeight.w700,
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place.name,
                                    style: AppText.ui(
                                      15,
                                      FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    place.price,
                                    style: AppText.ui(
                                      12,
                                      FontWeight.w500,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _pill(
                                    '✓ ${place.dietaryNote}',
                                    AppColors.blueSoft,
                                    const Color(0xFF1E40AF),
                                    size: 10,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _pill(
                                        place.category,
                                        AppColors.orangeSoft,
                                        AppColors.orange,
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (_selectedPlaceIds
                                                .contains(place.id)) {
                                              _selectedPlaceIds
                                                  .remove(place.id);
                                            } else {
                                              _selectedPlaceIds.add(place.id);
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _selectedPlaceIds
                                                    .contains(place.id)
                                                ? AppColors.greenSoft
                                                : AppColors.bg,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _selectedPlaceIds
                                                      .contains(place.id)
                                                  ? AppColors.greenText
                                                  : AppColors.border,
                                            ),
                                          ),
                                          child: Text(
                                            _selectedPlaceIds.contains(place.id)
                                                ? '✓ Added'
                                                : '+ Add to Itinerary',
                                            style: AppText.ui(
                                              11,
                                              FontWeight.w700,
                                              color: _selectedPlaceIds
                                                      .contains(place.id)
                                                  ? AppColors.greenText
                                                  : AppColors.navy,
                                            ),
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
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: TaraletsButton.orange(
                label: _selectedPlaceIds.isEmpty
                    ? 'Select Places to Continue'
                    : 'Build Itinerary (${_selectedPlaceIds.length}) →',
                onPressed: _selectedPlaceIds.isEmpty
                    ? null
                    : () {
                        context.go(AppRoutes.trips);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}