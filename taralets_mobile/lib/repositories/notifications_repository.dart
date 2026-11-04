import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_endpoints.dart';
import '../core/network/dio_client.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
    this.friendRequestId,
    this.tripJoinRequestId,
    this.tripId,
    this.requestStatus,
    this.actionable = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String type;
  final String? friendRequestId;
  final String? tripJoinRequestId;
  final String? tripId;
  final String? requestStatus;
  final bool actionable;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'].toString(),
        title: json['title'] as String? ?? 'Notification',
        message: json['message'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        type: json['type'] as String? ?? 'general',
        friendRequestId: json['friend_request_id']?.toString(),
        tripJoinRequestId: json['trip_join_request_id']?.toString(),
        tripId: json['trip_id']?.toString(),
        requestStatus: json['request_status'] as String?,
        actionable: json['actionable'] == true,
      );
}

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;
  String get _path => '${ApiEndpoints.apiPrefix}/notifications';

  Future<List<AppNotification>> getNotifications() async {
    final response = await _dio.get(_path);
    return (response.data as List)
        .map(
          (row) =>
              AppNotification.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> acceptFriendRequest(String requestId) async {
    await _dio.post(
      '${ApiEndpoints.apiPrefix}/friends/requests/$requestId/accept',
    );
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _dio.post(
      '${ApiEndpoints.apiPrefix}/friends/requests/$requestId/decline',
    );
  }

  Future<void> resolveTripJoinRequest({
    required String tripId,
    required String requestId,
    required bool approve,
  }) async {
    await _dio.post(
      '${ApiEndpoints.apiPrefix}/trips/$tripId/join-requests/$requestId/${approve ? 'approve' : 'reject'}',
    );
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

final notificationsRepoProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(dioProvider)),
);

final notificationsProvider = FutureProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationsRepoProvider).getNotifications(),
);
