import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/taralets_button.dart';

/// Dynamic GroupPrefs screen reflecting live user data
class GroupPrefsScreen extends StatefulWidget {
  final Trip trip;
  const GroupPrefsScreen({super.key, required this.trip});

  @override
  State<GroupPrefsScreen> createState() => _GroupPrefsScreenState();
}

class _GroupPrefsScreenState extends State<GroupPrefsScreen> {
  bool _showBreakdown = false;

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
    bool mono = false,
  }) => Container(
    padding: pad ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      t,
      style: mono
          ? AppText.mono(size, w, color: fg)
          : AppText.ui(size, w, color: fg),
    ),
  );

  Widget _statusPill(bool ok, String done, String wait) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: ok ? AppColors.greenSoft : AppColors.amberSoft,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      ok ? done : wait,
      style: AppText.ui(
        11,
        FontWeight.w700,
        color: ok ? AppColors.greenText : AppColors.amberText,
      ),
    ),
  );

  Widget _consensusBox(String label, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.ui(
            10,
            FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    ),
  );

  // Helper to dynamically calculate most popular preferences
  Map<String, int> _summarizePreferences() {
    Map<String, int> counts = {};
    for (var member in widget.trip.members) {
      for (var pref in member.preferences) {
        counts[pref] = (counts[pref] ?? 0) + 1;
      }
    }
    var entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    final bool allConfirmed = widget.trip.everyoneReady;
    final prefCounts = _summarizePreferences();

    // Grab top 3 tags safely
    final topTags = prefCounts.keys.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  BackButtonTile(onTap: () => context.pop()),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Preferences',
                        style: AppText.ui(
                          18,
                          FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'Progress status',
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

              // Group consensus
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: _card(
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.125),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Group Consensus',
                      style: AppText.ui(
                        13,
                        FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _consensusBox('ACTIVITY & INTEREST FOCUS', [
                      if (topTags.isEmpty)
                        Text(
                          "No preferences added yet",
                          style: AppText.ui(
                            11,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (int i = 0; i < topTags.length; i++)
                              _pill(
                                '${topTags[i]} (${prefCounts[topTags[i]]})',
                                i == 0 ? AppColors.navy : AppColors.orangeSoft,
                                i == 0 ? Colors.white : AppColors.orange,
                                w: i == 0 ? FontWeight.w700 : FontWeight.w600,
                              ),
                          ],
                        ),
                      const SizedBox(height: 3),
                      Text(
                        'Based on member selections',
                        style: AppText.ui(
                          10,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ]),

                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showBreakdown = !_showBreakdown),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'View Individual Member Breakdown',
                              style: AppText.ui(
                                12,
                                FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              _showBreakdown ? '▲' : '▼',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showBreakdown) ...[
                      const SizedBox(height: 10),
                      for (final m in widget.trip.members) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Avatar(name: m.name, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: AppText.ui(
                                        12,
                                        FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    if (m.preferences.isEmpty)
                                      Text(
                                        "No preferences set",
                                        style: AppText.ui(
                                          10,
                                          FontWeight.w400,
                                          color: AppColors.muted,
                                        ),
                                      )
                                    else
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: [
                                          for (final a in m.preferences)
                                            _pill(
                                              a,
                                              AppColors.orangeSoft,
                                              AppColors.orange,
                                              size: 10,
                                              pad: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 1,
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
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              ),

              // Preference status
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: _card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Preference Status',
                          style: AppText.ui(13, FontWeight.w700),
                        ),
                        Text(
                          '${widget.trip.readyCount}/${widget.trip.memberCount} members completed',
                          style: AppText.ui(
                            12,
                            FontWeight.w700,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final m in widget.trip.members) ...[
                      Row(
                        children: [
                          Avatar(name: m.name, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m.name,
                              style: AppText.ui(14, FontWeight.w700),
                            ),
                          ),
                          _statusPill(m.isReady, '✓ Ready', '⏳ Pending'),
                        ],
                      ),
                      if (m != widget.trip.members.last)
                        const SizedBox(height: 12),
                    ],

                    if (allConfirmed)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Text('🎉', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              "Everyone is ready to go!",
                              style: AppText.ui(
                                12,
                                FontWeight.w700,
                                color: AppColors.greenText,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              Opacity(
                opacity: allConfirmed ? 1 : 0.7,
                child: TaraletsButton.orange(
                  label: allConfirmed
                      ? 'Find Places →'
                      : 'Waiting for members...',
                  onPressed: () {
                    if (allConfirmed) {
                      context.push(AppRoutes.recommendations);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
