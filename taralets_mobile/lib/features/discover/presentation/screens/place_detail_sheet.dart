import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../data/manila_places.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/taralets_button.dart';

/// Place detail (Figma "Place Detail" screen), shown full-height over the tabs.
Future<void> showPlaceDetail(BuildContext context, Place place) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (_) => _PlaceDetail(place: place),
  );
}

class _PlaceDetail extends StatefulWidget {
  const _PlaceDetail({required this.place});
  final Place place;

  @override
  State<_PlaceDetail> createState() => _PlaceDetailState();
}

class _PlaceDetailState extends State<_PlaceDetail> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final filledStars = p.rating.round().clamp(0, 5);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 200,
            color: AppColors.bg,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(p.emoji, style: const TextStyle(fontSize: 80)),
                Positioned(
                  top: 12,
                  left: 12,
                  child: BackButtonTile(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => setState(() => _saved = !_saved),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AppIcons.heart(
                        filled: _saved,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: AppText.ui(
                          22,
                          FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        p.category,
                        style: AppText.ui(
                          10,
                          FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++) ...[
                      AppIcons.star(
                        color: i <= filledStars
                            ? AppColors.gold
                            : AppColors.border,
                      ),
                      if (i < 5) const SizedBox(width: 3),
                    ],
                    const SizedBox(width: 8),
                    Text('${p.rating}', style: AppText.ui(13, FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(
                      p.distanceLabel,
                      style: AppText.ui(
                        12,
                        FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final s in [
                      ('Entry', p.price),
                      ('Visit', '60 min'),
                      ('For groups', '✓ Yes'),
                    ]) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                s.$2,
                                style: AppText.ui(
                                  14,
                                  FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.$1,
                                style: AppText.ui(
                                  11,
                                  FontWeight.w400,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (s.$1 != 'For groups') const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Text('About', style: AppText.ui(13, FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  p.description,
                  style: AppText.ui(
                    13,
                    FontWeight.w400,
                    color: AppColors.muted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opening Hours',
                        style: AppText.ui(13, FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      for (final h in const [
                        ('Mon – Fri', '8:00 AM – 6:00 PM'),
                        ('Sat – Sun', '8:00 AM – 7:00 PM'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                h.$1,
                                style: AppText.ui(
                                  12,
                                  FontWeight.w400,
                                  color: AppColors.muted,
                                ),
                              ),
                              Text(
                                h.$2,
                                style: AppText.ui(12, FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    TaraletsButton.ghost(
                      label: 'View on Map',
                      full: false,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TaraletsButton.orange(
                        label: 'Add to Trip',
                        onPressed: () => Navigator.of(context).pop(),
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
}
