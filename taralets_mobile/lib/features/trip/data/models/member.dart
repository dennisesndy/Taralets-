/// Ready state of a trip member inside the Group Lobby.
enum MemberStatus { ready, notReady }

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
    this.preferredPace,
    this.accessibilityPreferences = const [],
  });

  /// User id (matches AuthUser.id for the signed-in user).
  final String id;

  /// Lowercase username without the leading @.
  final String username;

  /// Display name, e.g. "Dennise".
  final String name;

  final String? avatarUrl;
  final bool isLeader;
  final MemberStatus status;

  /// Legacy preference list retained for existing UI.
  final List<String> preferences;

  /// Structured individual trip preferences.
  final List<String> activityTags;
  final List<String> dietaryPreferences;
  final double? maxBudget;
  final String? preferredPace;
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
    String? preferredPace,
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
      preferredPace: preferredPace ?? this.preferredPace,
      accessibilityPreferences:
          accessibilityPreferences ?? this.accessibilityPreferences,
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    final tripPreferences =
        json['trip_preferences'] as Map<String, dynamic>? ?? {};

    return Member(
      id: json['user_id'].toString(),
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      isLeader: json['is_leader'] as bool? ?? false,
      status: (json['status'] as String?) == 'ready'
          ? MemberStatus.ready
          : MemberStatus.notReady,

      // Retain the existing field for compatibility.
      preferences: json['preferences'] != null
          ? List<String>.from(json['preferences'])
          : [],

      // Read the new structured fields from the backend.
      activityTags: List<String>.from(tripPreferences['activity_tags'] ?? []),
      dietaryPreferences: List<String>.from(
        tripPreferences['dietary_preferences'] ?? [],
      ),
      maxBudget: tripPreferences['max_budget'] != null
          ? (tripPreferences['max_budget'] as num).toDouble()
          : null,
      preferredPace: tripPreferences['preferred_pace'] as String?,
      accessibilityPreferences: List<String>.from(
        tripPreferences['accessibility_preferences'] ?? [],
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
      'preferred_pace': preferredPace,
      'accessibility_preferences': accessibilityPreferences,
    },
  };
}
