import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(ref.watch(dioProvider)),
);

final friendsProvider = FutureProvider<List<Friend>>(
  (ref) => ref.watch(friendsRepositoryProvider).listFriends(),
);

final incomingFriendRequestsProvider = FutureProvider<List<FriendRequestItem>>(
  (ref) => ref.watch(friendsRepositoryProvider).incomingRequests(),
);

final outgoingFriendRequestsProvider = FutureProvider<List<FriendRequestItem>>(
  (ref) => ref.watch(friendsRepositoryProvider).outgoingRequests(),
);

class Friend {
  const Friend({required this.id, required this.fullName, required this.email});

  final String id;
  final String fullName;
  final String email;

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    id: json['id'].toString(),
    fullName: json['full_name'] as String? ?? 'Taralets User',
    email: json['email'] as String? ?? '',
  );

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class FriendRequestItem {
  const FriendRequestItem({
    required this.requestId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.createdAt,
  });

  final String requestId;
  final String userId;
  final String fullName;
  final String email;
  final DateTime createdAt;

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) =>
      FriendRequestItem(
        requestId: json['request_id'].toString(),
        userId: json['user_id'].toString(),
        fullName: json['full_name'] as String? ?? 'Taralets User',
        email: json['email'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class FriendsRepository {
  FriendsRepository(this._dio);

  final Dio _dio;
  String get _path => '${ApiEndpoints.apiPrefix}/friends';

  Future<List<Friend>> listFriends() async {
    final response = await _dio.get(_path);
    return (response.data as List)
        .map((row) => Friend.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<FriendRequestItem>> incomingRequests() async {
    final response = await _dio.get('$_path/requests/incoming');
    return (response.data as List)
        .map(
          (row) =>
              FriendRequestItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<FriendRequestItem>> outgoingRequests() async {
    final response = await _dio.get('$_path/requests/outgoing');
    return (response.data as List)
        .map(
          (row) =>
              FriendRequestItem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<Friend> findByEmail(String email) async {
    final response = await _dio.get(
      '$_path/search',
      queryParameters: {'email': email.trim()},
    );
    return Friend.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Friend> addByEmail(String email) async {
    final response = await _dio.post(_path, data: {'email': email.trim()});
    return Friend.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> acceptRequest(String requestId) async {
    await _dio.post('$_path/requests/$requestId/accept');
  }

  Future<void> declineRequest(String requestId) async {
    await _dio.post('$_path/requests/$requestId/decline');
  }

  Future<void> remove(String friendId) async {
    await _dio.delete('$_path/$friendId');
  }

  String errorMessage(Object error, String fallback) {
    if (error is DioException) {
      final detail = error.response?.data;
      if (detail is Map && detail['detail'] is String) {
        return detail['detail'] as String;
      }
    }
    return fallback;
  }
}
