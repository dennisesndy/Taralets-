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
  });

  /// User id (matches `AuthUser.id` for the signed-in user).
  final String id;

  /// Lowercase username without the leading `@`.
  final String username;

  /// Display name, e.g. "Dennise".
  final String name;
  final String? avatarUrl;
  final bool isLeader;
  final MemberStatus status;

  /// The user's individual activity and dietary tags for calculating group consensus
  final List<String> preferences;

  bool get isReady => status == MemberStatus.ready;

  Member copyWith({
    String? name,
    String? avatarUrl,
    bool? isLeader,
    MemberStatus? status,
    List<String>? preferences,
  }) {
    return Member(
      id: id,
      username: username,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isLeader: isLeader ?? this.isLeader,
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['user_id'].toString(),
    username: json['username'] as String,
    name: json['name'] as String,
    avatarUrl: json['avatar_url'] as String?,
    isLeader: json['is_leader'] as bool? ?? false,
    status: (json['status'] as String?) == 'ready'
        ? MemberStatus.ready
        : MemberStatus.notReady,
    preferences: json['preferences'] != null
        ? List<String>.from(json['preferences'])
        : [],
  );

  Map<String, dynamic> toJson() => {
    'user_id': id,
    'username': username,
    'name': name,
    'avatar_url': avatarUrl,
    'is_leader': isLeader,
    'status': status == MemberStatus.ready ? 'ready' : 'not_ready',
    'preferences': preferences,
  };
}
