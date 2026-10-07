import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserPreferences {
  final List<String> activityTags;
  final List<String> dietary;

  UserPreferences({this.activityTags = const [], this.dietary = const []});

  UserPreferences copyWith({
    List<String>? activityTags,
    List<String>? dietary,
  }) {
    return UserPreferences(
      activityTags: activityTags ?? this.activityTags,
      dietary: dietary ?? this.dietary,
    );
  }
}

class UserPreferencesNotifier extends StateNotifier<UserPreferences> {
  UserPreferencesNotifier() : super(UserPreferences());

  void setPreferences({
    required List<String> activityTags,
    required List<String> dietary,
  }) {
    state = state.copyWith(activityTags: activityTags, dietary: dietary);
  }
}

final userPreferencesProvider =
    StateNotifierProvider<UserPreferencesNotifier, UserPreferences>((ref) {
      return UserPreferencesNotifier();
    });
