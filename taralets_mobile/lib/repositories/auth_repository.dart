import 'dart:async';
import 'package:dio/dio.dart';
import '../core/services/secure_storage_service.dart';
import '../core/network/api_endpoints.dart';

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

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'].toString(),
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    username: json['username'] as String? ?? '', // Optional
    tripsCount: (json['trips_count'] as num?)?.toInt() ?? 0,
    friendsCount: (json['friends_count'] as num?)?.toInt() ?? 0,
    placesCount: (json['places_count'] as num?)?.toInt() ?? 0,
  );

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
// Contract
// ---------------------------------------------------------------------------

abstract class AuthRepository {
  Future<AuthSession> login({required String email, required String password});
  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
  });
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String email, String otp, String newPassword);
  Future<AuthUser> me();
  Future<void> logout(); // Idinagdag ang logout
}

// ---------------------------------------------------------------------------
// Live API Implementation
// ---------------------------------------------------------------------------

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SecureStorageService _storage;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '${ApiEndpoints.apiPrefix}/auth/login',
        data: {'email': email, 'password': password},
      );

      final token = res.data['access_token'] as String;
      await _storage.saveToken(token);

      return AuthSession(
        user: const AuthUser(id: '', email: '', fullName: '', username: ''),
        accessToken: token,
      );
    } on DioException catch (e) {
      throw AuthException(e.response?.data['detail'] ?? 'Login failed.');
    }
  }

  @override
  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '${ApiEndpoints.apiPrefix}/auth/register',
        data: {'full_name': fullName, 'email': email, 'password': password},
      );
      return AuthSession(user: AuthUser.fromJson(res.data), accessToken: '');
    } on DioException catch (e) {
      throw AuthException(e.response?.data['detail'] ?? 'Registration failed.');
    }
  }

  @override
  Future<AuthUser> me() async {
    try {
      final res = await _dio.get('${ApiEndpoints.apiPrefix}/auth/me');
      return AuthUser.fromJson(res.data);
    } on DioException catch (_) {
      throw const AuthException('You are not signed in.');
    }
  }

  @override
  Future<void> logout() async {
    await _storage.deleteToken();
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _dio.post(
      '${ApiEndpoints.apiPrefix}/auth/forgot-password',
      data: {'email': email.trim()},
    );
  }

  @override
  Future<void> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    await _dio.post(
      '${ApiEndpoints.apiPrefix}/auth/reset-password',
      data: {
        'email': email.trim(),
        'otp_code': otp,
        'new_password': newPassword,
      },
    );
  }
}
