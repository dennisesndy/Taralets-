import 'package:flutter/material.dart';

import '../../data/models/itinerary_draft_models.dart';
import '../../data/models/itinerary_models.dart';

const List<ItineraryMember> _defaultDraftMembers = [
  ItineraryMember(name: 'Dennise'),
  ItineraryMember(name: 'Ana'),
  ItineraryMember(name: 'Paola'),
  ItineraryMember(name: 'Jewelle', isCurrentUser: true),
];

/// Local-only state for the add → vote → generate flow.
///
/// No API or database writes yet. The selected places and votes live here so
/// they survive while moving between Group Recommendations, Selected Places,
/// and the generated itinerary preview.
class ItineraryDraftController extends ChangeNotifier {
  ItineraryDraftController({
    List<ItineraryMember>? members,
    String currentUserName = 'Jewelle',
  }) : _members = List<ItineraryMember>.of(
         members ?? _defaultDraftMembers,
       ),
       _currentUserName = currentUserName;

  final List<ItineraryMember> _members;
  String _currentUserName;

  String get currentUserName => _currentUserName;

  final List<ItineraryCandidate> _selected = [];
  final Map<String, Set<String>> _votes = {};

  List<ItineraryMember> get members => List.unmodifiable(_members);
  List<ItineraryCandidate> get selected => List.unmodifiable(_selected);

  int get memberCount => _members.length;

  /// Replaces the preview members with the actual people who joined the trip.
  ///
  /// This is called after the trip is loaded so the group review card and the
  /// "You" badge refer to the logged-in account, not the local mock names.
  void updateGroupMembers({
    required List<ItineraryMember> members,
    required String currentUserName,
  }) {
    _members
      ..clear()
      ..addAll(members);
    _currentUserName = currentUserName;
    notifyListeners();
  }

  // Only the current user can cast votes in this local mock, so one real vote
  // is enough to include a place. The other members stay display-only until
  // the flow is wired to the backend.
  int get requiredVotes => 1;

  bool contains(String id) =>
      _selected.any((candidate) => candidate.id == id);

  void add(ItineraryCandidate candidate) {
    if (contains(candidate.id)) return;

    _selected.add(candidate);
    notifyListeners();
  }

  void remove(String id) {
    _selected.removeWhere((candidate) => candidate.id == id);
    _votes.remove(id);
    notifyListeners();
  }

  Set<String> votesFor(String id) =>
      Set.unmodifiable(_votes[id] ?? const <String>{});

  int voteCountFor(String id) => _votes[id]?.length ?? 0;

  bool currentUserVoted(String id) =>
      _votes[id]?.contains(currentUserName) ?? false;

  bool makesTheCut(ItineraryCandidate candidate) =>
      voteCountFor(candidate.id) >= requiredVotes;

  int get currentUserVoteCount => _selected
      .where((candidate) => currentUserVoted(candidate.id))
      .length;

  bool get canGenerate =>
      _selected.isNotEmpty && currentUserVoteCount > 0;

  void toggleCurrentUserVote(String id) {
    if (!contains(id)) return;

    final votes = _votes.putIfAbsent(id, () => <String>{});
    if (votes.contains(currentUserName)) {
      votes.remove(currentUserName);
    } else {
      votes.add(currentUserName);
    }
    notifyListeners();
  }

  ItineraryPlan? generatePlan({
    String title = 'Your Group Itinerary',
    String dateLabel = 'Trip day',
  }) {
    if (_selected.isEmpty) return null;

    final finalists = _selected
        .where((candidate) => voteCountFor(candidate.id) >= requiredVotes)
        .toList();

    if (finalists.isEmpty) return null;

    finalists.sort((a, b) {
      final voteOrder =
          voteCountFor(b.id).compareTo(voteCountFor(a.id));
      if (voteOrder != 0) return voteOrder;
      final scoreOrder = b.groupScore.compareTo(a.groupScore);
      if (scoreOrder != 0) return scoreOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final stops = _buildStops(finalists);
    if (stops.isEmpty) return null;

    return ItineraryPlan(
      title: title,
      dateLabel: dateLabel,
      status: ItineraryStatus.review,
      pace: 'Moderate',
      groupPreferences: _buildPreferences(finalists),
      days: [ItineraryDay(label: 'Day 1', stops: stops)],
      members: [
        for (final member in _members)
          ItineraryMember(
            name: member.name,
            reviewed: !member.isCurrentUser,
            isCurrentUser: member.isCurrentUser,
          ),
      ],
    );
  }

  List<ItineraryStop> _buildStops(List<ItineraryCandidate> finalists) {
    var cursor = const TimeOfDay(hour: 9, minute: 0);
    String? previousArea;
    final stops = <ItineraryStop>[];

    for (var index = 0; index < finalists.length; index++) {
      final candidate = finalists[index];
      final area = candidate.area.isEmpty
          ? candidate.category
          : candidate.area;
      final sameArea = previousArea != null &&
          previousArea.toLowerCase() == area.toLowerCase();
      final travelMinutes = index == 0 ? 0 : (sameArea ? 8 : 20);
      final travelCost = index == 0 ? 0 : (sameArea ? 0 : 20);

      cursor = _addMinutes(cursor, travelMinutes);
      final start = cursor;
      final duration = _durationFor(candidate.category);
      final end = _addMinutes(start, duration);

      stops.add(
        ItineraryStop(
          id: 'stop-${candidate.id}',
          placeId: candidate.placeId,
          name: candidate.name,
          category: candidate.category,
          icon: candidate.icon,
          startTime: start,
          endTime: end,
          durationMinutes: duration,
          budget: candidate.budget,
          travelMinutes: travelMinutes,
          travelCost: travelCost,
          area: area,
          activityTags: candidate.activityTags.take(4).toList(),
          dietaryTags: candidate.dietaryTags,
          accessibilityTags: candidate.accessibilityTags,
          pace: candidate.accessibilityTags.any(
                (tag) => tag.toLowerCase().contains('wheelchair'),
              )
              ? 'Easy'
              : 'Moderate',
          groupScore: candidate.groupScore,
          notes:
              'Selected by ${voteCountFor(candidate.id)} of '
              '${_members.length} group members.',
        ),
      );

      previousArea = area;
      cursor = end;
    }

    return stops;
  }

  List<String> _buildPreferences(List<ItineraryCandidate> finalists) {
    final tagCounts = <String, int>{};
    for (final candidate in finalists) {
      for (final tag in candidate.activityTags) {
        final normalized = tag.trim();
        if (normalized.isEmpty) continue;
        tagCounts[normalized] = (tagCounts[normalized] ?? 0) + 1;
      }
    }

    final topTags = tagCounts.entries.toList()
      ..sort((a, b) {
        final countOrder = b.value.compareTo(a.value);
        if (countOrder != 0) return countOrder;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    final preferences = <String>['Group vote'];
    preferences.addAll(topTags.take(2).map((entry) => entry.key));

    if (finalists.any((candidate) => candidate.dietaryTags.isNotEmpty)) {
      preferences.add('Diet-friendly');
    }
    if (finalists.any((candidate) => candidate.accessibilityTags.isNotEmpty)) {
      preferences.add('Accessible options');
    }

    final totalBudget = finalists.fold<int>(
      0,
      (sum, candidate) => sum + candidate.budget,
    );
    final averageBudget = (totalBudget / finalists.length).round();
    preferences.add(
      averageBudget == 0 ? 'Free' : '₱$averageBudget / person',
    );

    return preferences;
  }

  static int _durationFor(String category) {
    final value = category.toLowerCase();
    if (value.contains('food') ||
        value.contains('restaurant') ||
        value.contains('cafe') ||
        value.contains('eatery')) {
      return 60;
    }
    if (value.contains('museum') || value.contains('gallery')) {
      return 75;
    }
    if (value.contains('park') || value.contains('plaza')) {
      return 45;
    }
    if (value.contains('shopping') || value.contains('market')) {
      return 60;
    }
    if (value.contains('church') ||
        value.contains('historical') ||
        value.contains('heritage')) {
      return 45;
    }
    return 50;
  }

  static TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(
      hour: (total ~/ 60) % 24,
      minute: total % 60,
    );
  }
}
