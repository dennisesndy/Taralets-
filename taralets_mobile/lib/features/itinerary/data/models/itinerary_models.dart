import 'package:flutter/material.dart';

/// Formats a [TimeOfDay] like `2:30 PM`.
String formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// Formats minutes like `5h 30m`.
String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '${mins}m';
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}m';
}

enum ItineraryStatus { draft, review, finalized }

extension ItineraryStatusLabel on ItineraryStatus {
  String get label => switch (this) {
    ItineraryStatus.draft => 'Draft',
    ItineraryStatus.review => 'In review',
    ItineraryStatus.finalized => 'Finalized',
  };
}

class ItineraryStop {
  const ItineraryStop({
    required this.id,
    required this.placeId,
    required this.name,
    required this.category,
    required this.icon,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.budget,
    required this.travelMinutes,
    required this.travelCost,
    required this.area,
    this.activityTags = const [],
    this.dietaryTags = const [],
    this.accessibilityTags = const [],
    this.pace = 'Moderate',
    this.groupScore = 0,
    this.notes,
    this.latitude,
    this.longitude,
  });

  final String id;
  final int placeId;
  final String name;
  final String category;
  final String icon;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int durationMinutes;

  /// Budget in pesos. `0` means free.
  final int budget;
  final int travelMinutes;
  final int travelCost;
  final String area;
  final List<String> activityTags;
  final List<String> dietaryTags;
  final List<String> accessibilityTags;
  final String pace;
  final double groupScore;
  final String? notes;
  final double? latitude;
  final double? longitude;

  bool get isMeetup => category.toLowerCase() == 'meetup';

  String get startLabel => formatTimeOfDay(startTime);
  String get endLabel => formatTimeOfDay(endTime);
  String get timeRange => '$startLabel – $endLabel';
  String get budgetLabel => budget == 0 ? 'Free' : '₱$budget';
  String get groupScoreLabel => '${(groupScore * 100).round()}%';

  String get travelLabel {
    if (travelMinutes == 0) return '';
    final cost = travelCost > 0 ? '₱$travelCost' : 'Free';
    return '$travelMinutes min travel · $cost';
  }
}

class ItineraryMember {
  const ItineraryMember({
    required this.name,
    this.reviewed = false,
    this.isCurrentUser = false,
  });

  final String name;
  final bool reviewed;
  final bool isCurrentUser;

  ItineraryMember copyWith({bool? reviewed}) => ItineraryMember(
    name: name,
    reviewed: reviewed ?? this.reviewed,
    isCurrentUser: isCurrentUser,
  );
}

class ItineraryDay {
  const ItineraryDay({required this.label, required this.stops});

  final String label;
  final List<ItineraryStop> stops;

  ItineraryDay copyWith({List<ItineraryStop>? stops}) =>
      ItineraryDay(label: label, stops: stops ?? this.stops);
}

class ItineraryPlan {
  const ItineraryPlan({
    required this.title,
    required this.dateLabel,
    required this.status,
    required this.days,
    required this.members,
    required this.pace,
    required this.groupPreferences,
  });

  final String title;
  final String dateLabel;
  final ItineraryStatus status;
  final List<ItineraryDay> days;
  final List<ItineraryMember> members;
  final String pace;
  final List<String> groupPreferences;

  List<ItineraryStop> get stops => [
    for (final day in days) ...day.stops,
  ];

  int get totalStops => stops.length;
  int get totalDurationMinutes =>
      stops.fold(0, (sum, stop) => sum + stop.durationMinutes);
  int get totalTravelMinutes =>
      stops.fold(0, (sum, stop) => sum + stop.travelMinutes);
  int get totalBudget => stops.fold(0, (sum, stop) => sum + stop.budget);

  int get spanMinutes {
    if (stops.isEmpty) return 0;
    final start = stops.first.startTime;
    final end = stops.last.endTime;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes >= startMinutes) return endMinutes - startMinutes;
    return (24 * 60 - startMinutes) + endMinutes;
  }

  String get startLabel => stops.isEmpty ? '—' : stops.first.startLabel;
  String get endLabel => stops.isEmpty ? '—' : stops.last.endLabel;
  String get spanLabel => formatDuration(spanMinutes);
  String get totalBudgetLabel =>
      totalBudget == 0 ? 'Free' : '₱$totalBudget';
  String get totalTravelLabel => formatDuration(totalTravelMinutes);
  int get reviewedCount => members.where((member) => member.reviewed).length;
  bool get allReviewed => members.every((member) => member.reviewed);

  ItineraryPlan copyWith({
    String? title,
    String? dateLabel,
    ItineraryStatus? status,
    List<ItineraryDay>? days,
    List<ItineraryMember>? members,
    String? pace,
    List<String>? groupPreferences,
  }) => ItineraryPlan(
    title: title ?? this.title,
    dateLabel: dateLabel ?? this.dateLabel,
    status: status ?? this.status,
    days: days ?? this.days,
    members: members ?? this.members,
    pace: pace ?? this.pace,
    groupPreferences: groupPreferences ?? this.groupPreferences,
  );
}
