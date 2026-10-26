import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../repositories/trip_repository.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/ticket_card.dart'; // IDINAGDAG: TicketCard
import '../../../../core/utils/activity_category_helper.dart';

class GroupPrefsScreen extends ConsumerStatefulWidget {
  final Trip trip;

  const GroupPrefsScreen({super.key, required this.trip});

  @override
  ConsumerState<GroupPrefsScreen> createState() => _GroupPrefsScreenState();
}

class _GroupPrefsScreenState extends ConsumerState<GroupPrefsScreen> {
  bool _showBreakdown = false;
  late Trip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadCurrentTrip();
  }

  Future<void> _loadCurrentTrip() async {
    try {
      final current = await ref.read(tripRepositoryProvider).getTrip(widget.trip.id);
      if (mounted) setState(() => _trip = current);
    } catch (_) {
      // Keep the supplied trip snapshot available if a refresh is unavailable.
    }
  }

  Map<String, dynamic> _summarizePreferences() {
    final activities = <String, int>{};
    final dietary = <String, int>{};
    final accessibility = <String, int>{};
    final placeTargets = <int>[];
    final budgets = <double>[];

    for (final member in _trip.members) {
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

      if (member.desiredPlacesPerDay != null) placeTargets.add(member.desiredPlacesPerDay!);

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

    return {
      'activities': activities,
      'dietary': dietary,
      'accessibility': accessibility,
      'averagePlacesPerDay': placeTargets.isEmpty
          ? null
          : (placeTargets.reduce((a, b) => a + b) / placeTargets.length).round(),
      'placeTargetMemberCount': placeTargets.length,
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
            color: AppColors.primarySoft, // Pinalitan ng Rose tint
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
                style: AppText.ui(16, FontWeight.w900, color: AppColors.navy),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppText.ui(12, FontWeight.w500, color: AppColors.muted),
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
    bool darkTheme = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: darkTheme ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
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
                    10,
                    FontWeight.w800,
                    color: darkTheme ? Colors.white.withValues(alpha: 0.6) : AppColors.muted,
                    letterSpacing: 0.5,
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
            style: AppText.ui(18, FontWeight.w900, color: darkTheme ? Colors.white : AppColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(11, FontWeight.w500, color: darkTheme ? Colors.white.withValues(alpha: 0.7) : AppColors.muted),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: darkTheme ? Colors.white.withValues(alpha: 0.2) : AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  darkTheme ? AppColors.primaryLight : AppColors.primary, // Rose
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
      padding: const EdgeInsets.only(bottom: 16),
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
                        color: AppColors.primary, // Rose
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: AppText.ui(
                          13,
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
                '$count / $total',
                style: AppText.ui(
                  12,
                  FontWeight.w800,
                  color: highlighted ? AppColors.primary : AppColors.muted, // Rose
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: highlighted ? 8 : 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                highlighted ? AppColors.primary : AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, {bool emphasized = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.primarySoft : const Color(0xFFF4F5F7), // Rose tint
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: emphasized
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: AppText.ui(
          11,
          FontWeight.w700,
          color: emphasized ? AppColors.primary : AppColors.navy,
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
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(color: const Color(0xFFF8F9FB), radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppText.ui(13, FontWeight.w800, color: AppColors.navy),
                ),
              ),
              if (entries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${entries.length}',
                    style: AppText.ui(
                      11,
                      FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              emptyText,
              style: AppText.ui(12, FontWeight.w500, color: AppColors.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in entries)
                  _tag('${entry.key} • ${entry.value}'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _memberBreakdown() {
    return Column(
      children: [
        for (int i = 0; i < _trip.members.length; i++) ...[
          Builder(
            builder: (context) {
              final member = _trip.members[i];
              final hasPreferences =
                  member.activityTags.isNotEmpty ||
                  member.dietaryPreferences.isNotEmpty ||
                  member.accessibilityPreferences.isNotEmpty ||
                  member.desiredPlacesPerDay != null ||
                  member.maxBudget != null;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(
                  color: const Color(0xFFF8F9FB),
                  radius: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Avatar(name: member.name, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                style: AppText.ui(
                                  14,
                                  FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                member.isLeader
                                    ? 'Trip Leader'
                                    : 'Group Member',
                                style: AppText.ui(
                                  11,
                                  FontWeight.w500,
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
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!hasPreferences)
                      Text(
                        'No saved preferences',
                        style: AppText.ui(
                          12,
                          FontWeight.w500,
                          color: AppColors.muted,
                        ),
                      )
                    else ...[
                      if (member.activityTags.isNotEmpty) ...[
                        Text(
                          'ACTIVITIES',
                          style: AppText.ui(
                            10,
                            FontWeight.w800,
                            color: AppColors.muted,
                            letterSpacing: 0.5,
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
                        const SizedBox(height: 12),
                      ],
                      if (member.dietaryPreferences
                          .where((p) => p.toLowerCase() != 'none')
                          .isNotEmpty) ...[
                        Text(
                          'DIETARY',
                          style: AppText.ui(
                            10,
                            FontWeight.w800,
                            color: AppColors.muted,
                            letterSpacing: 0.5,
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
                        const SizedBox(height: 12),
                      ],
                      if (member.accessibilityPreferences.isNotEmpty) ...[
                        Text(
                          'ACCESSIBILITY',
                          style: AppText.ui(
                            10,
                            FontWeight.w800,
                            color: AppColors.muted,
                            letterSpacing: 0.5,
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
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (member.desiredPlacesPerDay != null)
                            _tag('📍 ${member.desiredPlacesPerDay} places/day'),
                          if (member.maxBudget != null)
                            _tag('💳 ${_formatPeso(member.maxBudget!)}'),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (i < _trip.members.length - 1) const SizedBox(height: 12),
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
          11,
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
    final averagePlacesPerDay = summary['averagePlacesPerDay'] as int?;
    final placeTargetMemberCount = summary['placeTargetMemberCount'] as int;
    final budgetAverage = summary['budgetAverage'] as double?;
    final budgetMemberCount = summary['budgetMemberCount'] as int;

    final memberCount = _trip.members.length;
    final allConfirmed = _trip.everyoneReady;

    final topActivity = activities.isEmpty ? null : activities.entries.first;
    final activityCount = topActivity?.value ?? 0;


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
                                20,
                                FontWeight.w900,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'What everyone wants to do',
                              style: AppText.ui(
                                13,
                                FontWeight.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft, // Rose tint
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$memberCount',
                              style: AppText.ui(
                                13,
                                FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // TICKET: Highlighted group overview.
                  TicketCard(
                    fillColor: AppColors.navy,
                    lineColor: const Color(0xFF334155),
                    notchAxis: TicketNotchAxis.leftRight,
                    notchOffset: 90,
                    cornerRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ticket Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Text(
                                  '✨',
                                  style: TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your Group, at a Glance',
                                      style: AppText.ui(
                                        17,
                                        FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'A summary of your shared travel preferences',
                                      style: AppText.ui(
                                        11,
                                        FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Ticket Body
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _metricCard(
                                      label: 'Top Interest',
                                      emoji: '🥇',
                                      value: topActivity?.key ?? 'Not set',
                                      subtitle: topActivity == null
                                          ? 'No activities saved'
                                          : '$activityCount of $memberCount members',
                                      progress: topActivity == null || memberCount == 0
                                          ? null
                                          : (activityCount / memberCount).clamp(0.0, 1.0).toDouble(),
                                      darkTheme: true,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _metricCard(
                                      label: 'Avg. Budget',
                                      emoji: '💳',
                                      value: budgetAverage == null
                                          ? 'Not set'
                                          : _formatPeso(budgetAverage),
                                      subtitle: budgetAverage == null
                                          ? 'No saved budgets'
                                          : '$budgetMemberCount of $memberCount members',
                                      progress: budgetProgress,
                                      darkTheme: true,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: 20,
                                      color: AppColors.primaryLight,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        topActivity == null
                                            ? 'Your group summary will appear once members save their preferences.'
                                            : '$activityCount of $memberCount members selected ${topActivity.key}. Use this to guide your itinerary.',
                                        style: AppText.ui(
                                          12,
                                          FontWeight.w500,
                                          color: Colors.white,
                                          height: 1.4,
                                        ),
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
                  const SizedBox(height: 24),

                  // Activity interest ranking.
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          emoji: '🧭',
                          title: 'Group Interests',
                          subtitle: 'See what your members want to explore.',
                        ),
                        const SizedBox(height: 24),
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
                          const SizedBox(height: 4),
                          Text(
                            'Ranked by the number of members who selected each activity. Members can choose more than one.',
                            style: AppText.ui(
                              11,
                              FontWeight.w500,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Travel needs.
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          emoji: '🎒',
                          title: 'Travel Needs',
                          subtitle:
                              'Keep important preferences in mind when planning.',
                        ),
                        const SizedBox(height: 20),
                        _needsSection(
                          emoji: '🍽️',
                          title: 'Dietary Preferences',
                          values: dietary,
                          emptyText: 'No specific dietary needs reported.',
                        ),
                        const SizedBox(height: 12),
                        _needsSection(
                          emoji: '♿',
                          title: 'Accessibility',
                          values: accessibility,
                          emptyText: 'No accessibility needs reported.',
                        ),
                        const SizedBox(height: 12),
                        _metricCard(
                          label: 'Average places per day',
                          emoji: '📍',
                          value: averagePlacesPerDay?.toString() ?? 'No target',
                          subtitle: averagePlacesPerDay == null
                              ? 'No members entered a target'
                              : 'Average from $placeTargetMemberCount member${placeTargetMemberCount == 1 ? '' : 's'}; rounded to a whole place',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          accessibility.isEmpty
                              ? 'No accessibility requirements selected.'
                              : 'Recommendations treat all selected member needs as group requirements: ${accessibility.keys.join(', ')}.',
                          style: AppText.ui(12, FontWeight.w600, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Individual preferences.
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              _showBreakdown = !_showBreakdown;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    '📋',
                                    style: TextStyle(fontSize: 22),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Individual Breakdown',
                                        style: AppText.ui(
                                          16,
                                          FontWeight.w900,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'View each member\'s saved preferences',
                                        style: AppText.ui(
                                          12,
                                          FontWeight.w500,
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
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox(width: double.infinity),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 20),
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
                  const SizedBox(height: 24),

                  // Readiness.
                  Container(
                    padding: const EdgeInsets.all(20),
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
                                  16,
                                  FontWeight.w900,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            Text(
                              '${_trip.readyCount}/${_trip.memberCount}',
                              style: AppText.ui(
                                14,
                                FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Check who is ready before moving on.',
                          style: AppText.ui(
                            12,
                            FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: _trip.memberCount == 0
                                ? 0
                                : (_trip.readyCount /
                                          _trip.memberCount)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                            minHeight: 8,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        for (
                          int i = 0;
                          i < _trip.members.length;
                          i++
                        ) ...[
                          Row(
                            children: [
                              Avatar(
                                name: _trip.members[i].name,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _trip.members[i].name,
                                      style: AppText.ui(
                                        14,
                                        FontWeight.w800,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                    if (_trip.members[i].isLeader)
                                      Text(
                                        'Trip leader',
                                        style: AppText.ui(
                                          11,
                                          FontWeight.w500,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _statusPill(_trip.members[i].isReady),
                            ],
                          ),
                          if (i < _trip.members.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                        ],
                        if (allConfirmed) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.greenText,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Everyone is ready to go!',
                                    style: AppText.ui(
                                      14,
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
                  const SizedBox(height: 20),
                  TaraletsButton.orange(
                    label: allConfirmed
                        ? 'Find Places'
                        : 'Waiting for members...',
                    onPressed: () {
                      if (allConfirmed) {
                        context.push(
                          AppRoutes.recommendations,
                          extra: {'groupId': _trip.id},
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: AppText.ui(13, FontWeight.w500, color: AppColors.muted),
      ),
    );
  }
}
