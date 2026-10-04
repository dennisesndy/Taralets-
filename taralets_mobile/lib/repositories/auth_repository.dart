import 'dart:async';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.username,
    this.tripsCount = 0,
    this.friendsCount = 0,
    this.placesCount = 0,
  });

  final String id;
  final String email;
  final String fullName;
  final String username;
  final int tripsCount;
  final int friendsCount;
  final int placesCount;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  /// JSON keys are a guess; adjust to your backend schema.
  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'].toString(),
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    username: json['username'] as String,
    tripsCount: (json['trips_count'] as num?)?.toInt() ?? 0,
    friendsCount: (json['friends_count'] as num?)?.toInt() ?? 0,
    placesCount: (json['places_count'] as num?)?.toInt() ?? 0,
  );

  /// "Dennise Sinday" -> "DS"
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  final AuthUser user;
  final String accessToken;
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Contract (mirrors the FastAPI backend)
// ---------------------------------------------------------------------------

abstract class AuthRepository {
  /// POST /api/v1/auth/login
  Future<AuthSession> login({required String email, required String password});

  /// POST /api/v1/auth/register
  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
  });

  /// GET /api/v1/auth/me
  Future<AuthUser> me();
}

// ---------------------------------------------------------------------------
// Mock implementation
// ---------------------------------------------------------------------------

/// In-memory fake. Starts "signed in" as the Figma demo user.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 300)});

  final Duration latency;

  AuthUser? _currentUser = const AuthUser(
    id: 'user_001',
    email: 'dennise@taralets.app',
    fullName: 'Dennise Sinday',
    username: 'dennise',
    tripsCount: 8,
    friendsCount: 24,
    placesCount: 32,
  );

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    if (email.trim().isEmpty || password.length < 6) {
      throw const AuthException('Incorrect email or password.');
    }
    final user = _currentUser!;
    return AuthSession(user: user, accessToken: 'mock-access-token');
  }

  @override
  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    if (email.trim().isEmpty || password.length < 6) {
      throw const AuthException(
        'Use a valid email and a password of at least 6 characters.',
      );
    }
    final user = AuthUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email.trim(),
      fullName: fullName.trim(),
      username: email.trim().split('@').first,
    );
    _currentUser = user;
    return AuthSession(user: user, accessToken: 'mock-access-token');
  }

  @override
  Future<AuthUser> me() async {
    await Future<void>.delayed(latency ~/ 2);
    final user = _currentUser;
    if (user == null) throw const AuthException('You are not signed in.');
    return user;
  }
}
