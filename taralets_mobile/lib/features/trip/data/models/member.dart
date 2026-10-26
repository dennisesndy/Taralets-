/// Ready state of a trip member inside the Group Lobby.
enum MemberStatus { ready, notReady }

List<String> _parseList(dynamic val) {
  if (val == null) return [];
  if (val is List) return val.map((e) => e.toString()).toList();
  return [];
}

double? _parseDoubleNull(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val);
  return null;
}

/// A person inside a trip lobby (leader or invited member).
class Member {
  const Member({
    required this.id,
    required this.username,
    required this.name,
    this.avatarUrl,
    this.isLeader = false,
    this.status = MemberStatus.notReady,
    this.preferences = const [],
    this.activityTags = const [],
    this.dietaryPreferences = const [],
    this.maxBudget,
    this.desiredPlacesPerDay,
    this.accessibilityPreferences = const [],
  });

  final String id;
  final String username;
  final String name;
  final String? avatarUrl;
  final bool isLeader;
  final MemberStatus status;

  final List<String> preferences;
  final List<String> activityTags;
  final List<String> dietaryPreferences;
  final double? maxBudget;
  final int? desiredPlacesPerDay;
  final List<String> accessibilityPreferences;

  bool get isReady => status == MemberStatus.ready;

  Member copyWith({
    String? name,
    String? avatarUrl,
    bool? isLeader,
    MemberStatus? status,
    List<String>? preferences,
    List<String>? activityTags,
    List<String>? dietaryPreferences,
    double? maxBudget,
    int? desiredPlacesPerDay,
    List<String>? accessibilityPreferences,
  }) {
    return Member(
      id: id,
      username: username,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isLeader: isLeader ?? this.isLeader,
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
      activityTags: activityTags ?? this.activityTags,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      maxBudget: maxBudget ?? this.maxBudget,
      desiredPlacesPerDay: desiredPlacesPerDay ?? this.desiredPlacesPerDay,
      accessibilityPreferences:
          accessibilityPreferences ?? this.accessibilityPreferences,
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    final tripPreferences =
        json['trip_preferences'] as Map<String, dynamic>? ??
        json['trip_member_preferences'] as Map<String, dynamic>? ??
        json['member_preferences'] as Map<String, dynamic>? ??
        {};

    return Member(
      id: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      isLeader: json['is_leader'] == true || json['is_leader'] == 'true',
      status: (json['status']?.toString() == 'ready')
          ? MemberStatus.ready
          : MemberStatus.notReady,
      preferences: _parseList(json['preferences']),
      activityTags: _parseList(tripPreferences['activity_tags']),
      dietaryPreferences: _parseList(tripPreferences['dietary_preferences']),
      maxBudget: _parseDoubleNull(tripPreferences['max_budget']),
      desiredPlacesPerDay: int.tryParse('${tripPreferences['desired_places_per_day'] ?? ''}'),
      accessibilityPreferences: _parseList(
        tripPreferences['accessibility_preferences'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': id,
    'username': username,
    'name': name,
    'avatar_url': avatarUrl,
    'is_leader': isLeader,
    'status': status == MemberStatus.ready ? 'ready' : 'not_ready',
    'preferences': preferences,
    'trip_preferences': {
      'activity_tags': activityTags,
      'dietary_preferences': dietaryPreferences,
      'max_budget': maxBudget,
      'desired_places_per_day': desiredPlacesPerDay,
      'accessibility_preferences': accessibilityPreferences,
    },
  };
}
