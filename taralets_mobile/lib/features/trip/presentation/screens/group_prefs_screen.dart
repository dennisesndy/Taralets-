import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../core/utils/activity_category_helper.dart';


class GroupPrefsScreen extends StatefulWidget {
  final Trip trip;

  const GroupPrefsScreen({super.key, required this.trip});

  @override
  State<GroupPrefsScreen> createState() => _GroupPrefsScreenState();
}

class _GroupPrefsScreenState extends State<GroupPrefsScreen> {
  bool _showBreakdown = false;

  Map<String, dynamic> _summarizePreferences() {
    final activities = <String, int>{};
    final dietary = <String, int>{};
    final accessibility = <String, int>{};
    final pace = <String, int>{};
    final budgets = <double>[];

    for (final member in widget.trip.members) {
      for (final tag in normalizeActivityCategories(
          member.activityTags,
        )) {
          activities[tag] = (activities[tag] ?? 0) + 1;
        }

      for (final pref in member.dietaryPreferences.toSet()) {
        if (pref.toLowerCase() == 'none') continue;
        dietary[pref] = (dietary[pref] ?? 0) + 1;
      }

      for (final pref in member.accessibilityPreferences.toSet()) {
        accessibility[pref] = (accessibility[pref] ?? 0) + 1;
      }

      final memberPace = member.preferredPace;
      if (memberPace != null && memberPace.trim().isNotEmpty) {
        pace[memberPace] = (pace[memberPace] ?? 0) + 1;
      }

      if (member.maxBudget != null) {
        budgets.add(member.maxBudget!);
      }
    }

    void sortCounts(Map<String, int> values) {
      final sorted = values.entries.toList()
        ..sort((a, b) {
          final countOrder = b.value.compareTo(a.value);
          return countOrder != 0 ? countOrder : a.key.compareTo(b.key);
        });

      values
        ..clear()
        ..addEntries(sorted);
    }

    sortCounts(activities);
    sortCounts(dietary);
    sortCounts(accessibility);
    sortCounts(pace);

    return {
      'activities': activities,
      'dietary': dietary,
      'accessibility': accessibility,
      'pace': pace,
      'budgetAverage': budgets.isEmpty
          ? null
          : budgets.reduce((a, b) => a + b) / budgets.length,
      'budgetMemberCount': budgets.length,
    };
  }

  String _formatPeso(double amount) {
    final digits = amount.round().toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '₱$formatted';
  }

  BoxDecoration _cardDecoration({
    Color? color,
    Color? borderColor,
    double radius = 20,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _sectionTitle({
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.orangeSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 21)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.ui(15, FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required String emoji,
    required String value,
    required String subtitle,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(color: const Color(0xFFF7F8FA), radius: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppText.ui(
                    9,
                    FontWeight.w800,
                    color: AppColors.muted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(19, FontWeight.w900, color: AppColors.navy),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(10, FontWeight.w500, color: AppColors.muted),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.orange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _interestBar({
    required String label,
    required int count,
    required int total,
    bool highlighted = false,
  }) {
    final ratio = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (highlighted) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: AppText.ui(
                          12,
                          highlighted ? FontWeight.w800 : FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count/$total',
                style: AppText.ui(
                  11,
                  FontWeight.w800,
                  color: highlighted ? AppColors.orange : AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: highlighted ? 8 : 6,
              backgroundColor: const Color(0xFFF0E8E2),
              valueColor: AlwaysStoppedAnimation<Color>(
                highlighted ? AppColors.orange : AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, {bool emphasized = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.orangeSoft : const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: emphasized
              ? AppColors.orange.withValues(alpha: 0.18)
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: AppText.ui(
          10,
          FontWeight.w700,
          color: emphasized ? AppColors.orange : AppColors.navy,
        ),
      ),
    );
  }

  Widget _needsSection({
    required String emoji,
    required String title,
    required Map<String, int> values,
    required String emptyText,
  }) {
    final entries = values.entries.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(color: const Color(0xFFF8F9FB), radius: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppText.ui(12, FontWeight.w800, color: AppColors.navy),
                ),
              ),
              if (entries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orangeSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${entries.length}',
                    style: AppText.ui(
                      10,
                      FontWeight.w800,
                      color: AppColors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          if (entries.isEmpty)
            Text(
              emptyText,
              style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final entry in entries)
                  _tag('${entry.key} · ${entry.value}'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _memberBreakdown() {
    return Column(
      children: [
        for (int i = 0; i < widget.trip.members.length; i++) ...[
          Builder(
            builder: (context) {
              final member = widget.trip.members[i];

              final hasPreferences =
                  member.activityTags.isNotEmpty ||
                  member.dietaryPreferences.isNotEmpty ||
                  member.accessibilityPreferences.isNotEmpty ||
                  member.preferredPace != null ||
                  member.maxBudget != null;

              return Container(
                padding: const EdgeInsets.all(13),
                decoration: _cardDecoration(
                  color: const Color(0xFFF8F9FB),
                  radius: 15,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Avatar(name: member.name, size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                style: AppText.ui(
                                  12,
                                  FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                member.isLeader
                                    ? 'Trip leader'
                                    : 'Group member',
                                style: AppText.ui(
                                  10,
                                  FontWeight.w400,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (member.isReady)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.greenText,
                            size: 19,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!hasPreferences)
                      Text(
                        'No saved preferences',
                        style: AppText.ui(
                          11,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      )
                    else ...[
                      if (member.activityTags.isNotEmpty) ...[
                        Text(
                          'ACTIVITIES',
                          style: AppText.ui(
                            9,
                            FontWeight.w800,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in member.activityTags)
                              _tag(tag, emphasized: true),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (member.dietaryPreferences
                          .where((p) => p.toLowerCase() != 'none')
                          .isNotEmpty) ...[
                        Text(
                          'DIETARY',
                          style: AppText.ui(
                            9,
                            FontWeight.w800,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final pref in member.dietaryPreferences)
                              if (pref.toLowerCase() != 'none') _tag(pref),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (member.accessibilityPreferences.isNotEmpty) ...[
                        Text(
                          'ACCESSIBILITY',
                          style: AppText.ui(
                            9,
                            FontWeight.w800,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final pref in member.accessibilityPreferences)
                              _tag(pref),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (member.preferredPace != null)
                            _tag('🚶 ${member.preferredPace}'),
                          if (member.maxBudget != null)
                            _tag('💰 ${_formatPeso(member.maxBudget!)}'),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (i < widget.trip.members.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _statusPill(bool ready) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ready ? AppColors.greenSoft : AppColors.amberSoft,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        ready ? '✓ Ready' : 'Pending',
        style: AppText.ui(
          10,
          FontWeight.w800,
          color: ready ? AppColors.greenText : AppColors.amberText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summarizePreferences();

    final activities = summary['activities'] as Map<String, int>;
    final dietary = summary['dietary'] as Map<String, int>;
    final accessibility = summary['accessibility'] as Map<String, int>;
    final pace = summary['pace'] as Map<String, int>;
    final budgetAverage = summary['budgetAverage'] as double?;
    final budgetMemberCount = summary['budgetMemberCount'] as int;

    final memberCount = widget.trip.members.length;
    final allConfirmed = widget.trip.everyoneReady;
    final topActivity = activities.isEmpty ? null : activities.entries.first;
    final activityCount = topActivity?.value ?? 0;

    final topPace = pace.isEmpty ? null : pace.entries.first;
    final budgetProgress = budgetAverage == null
        ? null
        : (budgetAverage / 10000).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BackButtonTile(onTap: () => context.pop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group Preferences',
                              style: AppText.ui(
                                19,
                                FontWeight.w900,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Everyone’s preferences in one place',
                              style: AppText.ui(
                                11,
                                FontWeight.w400,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.orangeSoft,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              size: 15,
                              color: AppColors.orange,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$memberCount',
                              style: AppText.ui(
                                12,
                                FontWeight.w800,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Highlighted group overview.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF4EB), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: 0.06),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Text(
                                '🧭',
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Group, at a Glance',
                                    style: AppText.ui(
                                      16,
                                      FontWeight.w900,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'A summary of your shared travel preferences',
                                    style: AppText.ui(
                                      10,
                                      FontWeight.w400,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _metricCard(
                                label: 'Top Interest',
                                emoji: '🏛️',
                                value: topActivity?.key ?? 'Not set',
                                subtitle: topActivity == null
                                    ? 'No activities saved'
                                    : '$activityCount of $memberCount members',
                                progress:
                                    topActivity == null || memberCount == 0
                                    ? null
                                    : (activityCount / memberCount)
                                          .clamp(0.0, 1.0)
                                          .toDouble(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _metricCard(
                                label: 'Avg. Budget',
                                emoji: '💰',
                                value: budgetAverage == null
                                    ? 'Not set'
                                    : _formatPeso(budgetAverage),
                                subtitle: budgetAverage == null
                                    ? 'No saved budgets'
                                    : '$budgetMemberCount of $memberCount members',
                                progress: budgetProgress,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 19,
                                color: AppColors.orange,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  topActivity == null
                                      ? 'Your group summary will appear once members save their preferences.'
                                      : '$activityCount of $memberCount members selected ${topActivity.key}. Use this as a starting point for your group itinerary.',
                                  style: AppText.ui(
                                    11,
                                    FontWeight.w500,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Activity interest ranking.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          emoji: '🎯',
                          title: 'Group Interests',
                          subtitle: 'See what your members want to explore.',
                        ),
                        const SizedBox(height: 22),
                        if (activities.isEmpty)
                          _emptyMessage('No activity preferences saved yet.')
                        else ...[
                          for (final entry in activities.entries)
                            _interestBar(
                              label: entry.key,
                              count: entry.value,
                              total: memberCount,
                              highlighted: entry.key == topActivity?.key,
                            ),
                          const SizedBox(height: 1),
                          Text(
                            'Ranked by the number of members who selected each activity. Members can choose more than one.',
                            style: AppText.ui(
                              10,
                              FontWeight.w400,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Travel needs.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          emoji: '🧩',
                          title: 'Travel Needs',
                          subtitle:
                              'Keep important preferences in mind when planning.',
                        ),
                        const SizedBox(height: 17),
                        _needsSection(
                          emoji: '🥗',
                          title: 'Dietary Preferences',
                          values: dietary,
                          emptyText: 'No specific dietary needs reported.',
                        ),
                        const SizedBox(height: 10),
                        _needsSection(
                          emoji: '♿',
                          title: 'Accessibility',
                          values: accessibility,
                          emptyText: 'No accessibility needs reported.',
                        ),
                        const SizedBox(height: 10),
                        _needsSection(
                          emoji: '🚶',
                          title: 'Preferred Pace',
                          values: pace,
                          emptyText: 'No pace preferences saved yet.',
                        ),
                        if (topPace != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: AppColors.orangeSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.directions_walk_rounded,
                                  color: AppColors.orange,
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${topPace.key} is the most selected pace (${topPace.value}/$memberCount members).',
                                    style: AppText.ui(
                                      10,
                                      FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Individual preferences.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _showBreakdown = !_showBreakdown;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.orangeSoft,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Text(
                                    '👥',
                                    style: TextStyle(fontSize: 21),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Individual Breakdown',
                                        style: AppText.ui(
                                          14,
                                          FontWeight.w800,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'View each member’s saved preferences',
                                        style: AppText.ui(
                                          10,
                                          FontWeight.w400,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _showBreakdown
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.navy,
                                  size: 25,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox(width: double.infinity),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _memberBreakdown(),
                          ),
                          crossFadeState: _showBreakdown
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 250),
                          sizeCurve: Curves.easeInOut,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Readiness.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Preference Status',
                                style: AppText.ui(
                                  15,
                                  FontWeight.w900,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            Text(
                              '${widget.trip.readyCount}/${widget.trip.memberCount}',
                              style: AppText.ui(
                                13,
                                FontWeight.w900,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Check who is ready before moving on.',
                          style: AppText.ui(
                            11,
                            FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 15),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: widget.trip.memberCount == 0
                                ? 0
                                : (widget.trip.readyCount /
                                          widget.trip.memberCount)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                            minHeight: 7,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 17),
                        for (
                          int i = 0;
                          i < widget.trip.members.length;
                          i++
                        ) ...[
                          Row(
                            children: [
                              Avatar(
                                name: widget.trip.members[i].name,
                                size: 36,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.trip.members[i].name,
                                      style: AppText.ui(
                                        12,
                                        FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    if (widget.trip.members[i].isLeader)
                                      Text(
                                        'Trip leader',
                                        style: AppText.ui(
                                          10,
                                          FontWeight.w400,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _statusPill(widget.trip.members[i].isReady),
                            ],
                          ),
                          if (i < widget.trip.members.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 11),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                        ],
                        if (allConfirmed) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.greenText,
                                  size: 20,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Everyone is ready to go!',
                                    style: AppText.ui(
                                      12,
                                      FontWeight.w800,
                                      color: AppColors.greenText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  TaraletsButton.orange(
                    label: allConfirmed
                        ? 'Find Places →'
                        : 'Waiting for members...',
                    onPressed: () {
                      if (allConfirmed) {
                        context.push(
                          AppRoutes.recommendations,
                          extra: {'groupId': widget.trip.id}, // Ito ang idinagdag
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        message,
        style: AppText.ui(11, FontWeight.w400, color: AppColors.muted),
      ),
    );
  }
}
