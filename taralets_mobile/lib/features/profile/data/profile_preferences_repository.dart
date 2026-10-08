import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';

final profilePreferencesRepoProvider = Provider<ProfilePreferencesRepository>((
  ref,
) {
  return ProfilePreferencesRepository(ref.read(dioProvider));
});

class ProfilePreferencesRepository {
  final Dio _dio;

  ProfilePreferencesRepository(this._dio);

  Future<Map<String, dynamic>?> getPreferences() async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.apiPrefix}/profile/preferences',
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> savePreferences({
    required List<String> activityTags,
    required List<String> dietaryPreferences,
    double maxBudget = 2500.0,
    String preferredPace = 'Moderate',
    String passengerType = 'Regular',
    List<String> accessibilityPreferences = const [],
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.apiPrefix}/profile/preferences',
        data: {
          'activity_tags': activityTags,
          'dietary_preferences': dietaryPreferences,
          'max_budget': maxBudget,
          'preferred_pace': preferredPace,
          'passenger_type': passengerType,
          'accessibility_preferences': accessibilityPreferences,
        },
      );
    } on DioException catch (e) {
      print('=== PROFILE PREFERENCES ERROR ===');
      print('STATUS: ${e.response?.statusCode}');
      print('RESPONSE: ${e.response?.data}');
      print('REQUEST URL: ${e.requestOptions.uri}');
      print('HEADERS: ${e.requestOptions.headers}');
      print('=================================');
      rethrow;
    }
  }

  Future<void> saveTripPreferences({
    required String tripId,
    required List<String> activityTags,
    required List<String> dietaryPreferences,
    double maxBudget = 2500.0,
    String preferredPace = 'Moderate',
    List<String> accessibilityPreferences = const [],
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.apiPrefix}/trips/$tripId/member-preferences',
        data: {
          'activity_tags': activityTags,
          'dietary_preferences': dietaryPreferences,
          'max_budget': maxBudget,
          'preferred_pace': preferredPace,
          'accessibility_preferences': accessibilityPreferences,
          'passenger_type': 'Regular',
        },
      );
    } on DioException catch (e) {
      print('=== TRIP PREFERENCES ERROR ===');
      print('STATUS: ${e.response?.statusCode}');
      print('RESPONSE: ${e.response?.data}');
      print('REQUEST URL: ${e.requestOptions.uri}');
      print('HEADERS: ${e.requestOptions.headers}');
      print('=================================');
      rethrow;
    }
  }
}
