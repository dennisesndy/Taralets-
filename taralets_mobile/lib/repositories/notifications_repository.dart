import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simpleng Model para sa Notification
class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: json['title'] ?? 'Notification',
      message: json['message'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// Repository na kukuha sa Backend API
class NotificationsRepository {
  final Dio _dio;
  NotificationsRepository(this._dio);

  Future<List<AppNotification>> getNotifications() async {
    try {
      // Pinapalagay natin na ito ang endpoint ng inyong backend
      final res = await _dio.get('http://10.0.2.2:8000/api/v1/notifications');
      final data = res.data as List;
      return data.map((e) => AppNotification.fromJson(e)).toList();
    } catch (e) {
      // Return empty list kung walang API o may error para hindi mag-crash
      return []; 
    }
  }
}

// Provider para magamit natin sa Screen
final dioProvider = Provider((ref) => Dio()); // Basic Dio instance
final notificationsRepoProvider = Provider((ref) => NotificationsRepository(ref.read(dioProvider)));

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  return ref.read(notificationsRepoProvider).getNotifications();
});