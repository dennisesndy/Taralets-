import 'package:flutter/material.dart';

import 'models/itinerary_draft_models.dart';
import 'models/itinerary_models.dart';

/// Converts the backend's trip itinerary response into the screen model.
///
/// The backend owns ordering, scores, travel estimates, and scheduling. This
/// mapper only normalizes the payload so the existing itinerary UI can render
/// it without any local mock generation.
ItineraryPlan itineraryPlanFromApi(Map<String, dynamic> data) {
  final members = <ItineraryMember>[];

  final rawMembers = data['members'];
  if (rawMembers is List) {
    for (final item in rawMembers) {
      if (item is! Map) continue;

      final member = Map<String, dynamic>.from(item);
      final isCurrentUser = member['is_current_user'] == true;
      final name = _text(
        member['name'],
        _text(member['username'], 'Member'),
      );

      members.add(
        ItineraryMember(
          name: name,
          isCurrentUser: isCurrentUser,
          reviewed: member['reviewed'] is bool
              ? member['reviewed'] as bool
              : !isCurrentUser,
        ),
      );
    }
  }

  if (members.isEmpty) {
    members.add(const ItineraryMember(
      name: 'You',
      isCurrentUser: true,
    ));
  }

  final stops = <ItineraryStop>[];
  final rawStops = data['stops'];

  if (rawStops is List) {
    for (var index = 0; index < rawStops.length; index++) {
      final item = rawStops[index];
      if (item is! Map) continue;

      final stop = Map<String, dynamic>.from(item);
      final name = _text(stop['name'], 'Stop');
      final category = _text(stop['category'], 'Other');
      final duration = _int(stop['duration_minutes'], 50);
      final start = _parseTime(stop['start_time']);
      final end = _parseTime(
        stop['end_time'],
        _addMinutes(start, duration),
      );
      final placeId = _int(stop['id'], _int(stop['place_id']));
      final warning = _text(stop['warning']);

      stops.add(
        ItineraryStop(
          id: 'stop-$placeId-$index',
          placeId: placeId,
          name: name,
          category: category,
          icon: itineraryIconForCategory(category),
          startTime: start,
          endTime: end,
          durationMinutes: duration,
          budget: _int(stop['budget']),
          travelMinutes: _int(stop['travel_minutes']),
          travelCost: _int(stop['travel_cost']),
          area: _text(stop['area'], _text(stop['district'])),
          activityTags: _stringList(stop['activity_tags']),
          dietaryTags: _stringList(stop['dietary_tags']),
          accessibilityTags: _stringList(stop['accessibility_tags']),
          pace: _text(data['pace'], 'Moderate'),
          groupScore: _double(stop['group_score']),
          notes: warning.isEmpty ? null : warning,
          latitude: _nullableDouble(stop['latitude']),
          longitude: _nullableDouble(stop['longitude']),
        ),
      );
    }
  }

  return ItineraryPlan(
    title: _text(data['title'], 'Group Itinerary'),
    dateLabel: _text(data['date_label'], 'Trip day'),
    status: ItineraryStatus.review,
    days: [ItineraryDay(label: 'Day 1', stops: stops)],
    members: members,
    pace: _text(data['pace'], 'Moderate'),
    groupPreferences: _stringList(data['group_preferences']),
  );
}

String _text(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'none' ? fallback : text;
}

int _int(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _double(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return [
      for (final item in value)
        if (item != null && item.toString().trim().isNotEmpty)
          item.toString().trim(),
    ];
  }

  if (value is String) {
    return [
      for (final item in value.split(','))
        if (item.trim().isNotEmpty) item.trim(),
    ];
  }

  return const [];
}

TimeOfDay _parseTime(
  dynamic value, [
  TimeOfDay fallback = const TimeOfDay(hour: 9, minute: 0),
]) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return fallback;

  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
  if (match == null) return fallback;

  var hour = int.tryParse(match.group(1)!) ?? fallback.hour;
  final minute = int.tryParse(match.group(2)!) ?? fallback.minute;
  final upper = text.toUpperCase();

  if (upper.contains('PM') && hour < 12) hour += 12;
  if (upper.contains('AM') && hour == 12) hour = 0;

  return TimeOfDay(
    hour: hour % 24,
    minute: minute < 0 ? 0 : (minute > 59 ? 59 : minute),
  );
}

TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
  final total = time.hour * 60 + time.minute + minutes;
  return TimeOfDay(
    hour: (total ~/ 60) % 24,
    minute: total % 60,
  );
}
