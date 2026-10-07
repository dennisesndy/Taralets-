import 'package:flutter/material.dart';

/// Group preferences chosen in Create Trip step 4 (Figma "Group Preferences").
class GroupPreferences {
  const GroupPreferences({
    this.categories = const ['Historical', 'Cultural', 'Food'],
    this.budget = '₱₱', // ₱ / ₱₱ / ₱₱₱ (for consensus mock)
    this.walking = 'Moderate', // Light Walking / Moderate / Walking Trip
  });

  final List<String> categories;
  final String budget;
  final String walking;

  GroupPreferences copyWith({
    List<String>? categories,
    String? budget,
    String? walking,
  }) {
    return GroupPreferences(
      categories: categories ?? this.categories,
      budget: budget ?? this.budget,
      walking: walking ?? this.walking,
    );
  }
}

/// Everything the 5-step Create Trip wizard collects.
class CreateTripDto {
  const CreateTripDto({
    required this.code,
    required this.title,
    this.description = '',
    required this.date,
    required this.meetupTime,
    required this.wrapUpTime,
    required this.meetupName,
    required this.latitude,
    required this.longitude,
    required this.memberNames,
    required this.preferences,
  });

  /// Room code, e.g. `TARA-88` (generated when the wizard opens so the Invite
  /// step and the success screen show the same code).
  final String code;
  final String title;
  final String description;
  final DateTime date;
  final TimeOfDay meetupTime;
  final TimeOfDay wrapUpTime;
  final String meetupName;
  final double latitude;
  final double longitude;

  /// Leader first.
  final List<String> memberNames;
  final GroupPreferences preferences;
}
