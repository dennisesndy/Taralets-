import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/taralets_button.dart';

/// Figma `GroupPrefs` ("View Trip" after creating): consensus card and
/// per-member preference status. Replaces the invented "Trip Lobby" screen.
class GroupPrefsScreen extends StatefulWidget {
  const GroupPrefsScreen({super.key});

  @override
  State<GroupPrefsScreen> createState() => _GroupPrefsScreenState();
}

class _GroupPrefsScreenState extends State<GroupPrefsScreen> {
  bool _allConfirmed = false;
  bool _showBreakdown = false;

  static const _members = [
    (
      name: 'Dennise',
      budget: '₱₱',
      activities: ['Historical', 'Cultural'],
      dietary: 'None',
    ),
    (
      name: 'Ana',
      budget: '₱₱',
      activities: ['Food', 'Historical'],
      dietary: 'Halal',
    ),
    (
      name: 'Paola',
      budget: '₱',
      activities: ['Cafe', 'Cultural'],
      dietary: 'Vegan',
    ),
    (
      name: 'Jewelle',
      budget: '₱₱',
      activities: ['Cultural', 'Nightlife'],
      dietary: 'None',
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

  @override
  Widget build(BuildContext context) {
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
                  BackButtonTile(onTap: () => context.go(AppRoutes.trips)),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Group Consensus',
                          style: AppText.ui(
                            13,
                            FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        _pill(
                          '95% Match',
                          AppColors.greenSoft,
                          AppColors.greenText,
                          w: FontWeight.w800,
                          pad: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _consensusBox('BUDGET CONSENSUS', [
                      Text(
                        '₱₱ (Moderate Budget)',
                        style: AppText.ui(
                          12,
                          FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Resolved across 4 members',
                        style: AppText.ui(
                          10,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _consensusBox('DIETARY & DINING CONSENSUS', [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final d in ['Halal', 'Vegan option included'])
                            _pill(
                              '✓ $d',
                              const Color(0xFFDCFCE7),
                              const Color(0xFF166534),
                            ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _consensusBox('ACTIVITY FOCUS', [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _pill(
                            'Historical & Cultural',
                            AppColors.navy,
                            Colors.white,
                            w: FontWeight.w700,
                          ),
                          _pill('Cafe', AppColors.orangeSoft, AppColors.orange),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Primary · Secondary',
                        style: AppText.ui(
                          10,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blueSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Group Match Score',
                                style: AppText.ui(
                                  11,
                                  FontWeight.w700,
                                  color: const Color(0xFF1E40AF),
                                ),
                              ),
                              Text(
                                '95%',
                                style: AppText.mono(
                                  13,
                                  FontWeight.w800,
                                  color: const Color(0xFF1E40AF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBFDBFE),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: 0.95,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Based on everyone's preferences",
                            style: AppText.ui(
                              10,
                              FontWeight.w400,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      for (final m in _members) ...[
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
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        _pill(
                                          m.budget,
                                          AppColors.greenSoft,
                                          AppColors.greenText,
                                          size: 10,
                                          w: FontWeight.w700,
                                          mono: true,
                                          pad: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                        ),
                                        for (final a in m.activities)
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
                                        if (m.dietary != 'None')
                                          _pill(
                                            m.dietary,
                                            const Color(0xFFDCFCE7),
                                            const Color(0xFF166534),
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
                          '${_allConfirmed ? '4/4' : '3/4'} members completed',
                          style: AppText.ui(
                            12,
                            FontWeight.w700,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final m in _members) ...[
                      Row(
                        children: [
                          Avatar(name: m.name, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: AppText.ui(14, FontWeight.w700),
                                ),
                                if (m.name == 'Ana')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Historical • Food • ₱₱',
                                      style: AppText.ui(
                                        11,
                                        FontWeight.w400,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _statusPill(
                            m.name != 'Jewelle' || _allConfirmed,
                            '✓ Confirmed',
                            '⏳ Selecting...',
                          ),
                        ],
                      ),
                      if (m != _members.last) const SizedBox(height: 12),
                    ],
                    if (!_allConfirmed)
                      GestureDetector(
                        onTap: () => setState(() => _allConfirmed = true),
                        child: Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '▶ Simulate: Jewelle confirms',
                            style: AppText.ui(
                              13,
                              FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      )
                    else
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
                              "Everyone's preferences are ready!",
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
                opacity: _allConfirmed ? 1 : 0.7,
                child: TaraletsButton.orange(
                  label: _allConfirmed
                      ? 'Find Places →'
                      : 'Waiting for members...',
                  onPressed: () {
                    if (_allConfirmed) {
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
