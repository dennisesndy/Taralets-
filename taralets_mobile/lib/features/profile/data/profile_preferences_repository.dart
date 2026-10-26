import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/secure_storage_service.dart';

final profilePreferencesRepoProvider = Provider<ProfilePreferencesRepository>((
  ref,
) {
  return ProfilePreferencesRepository(
    ref.read(dioProvider),
    ref.read(secureStorageProvider),
  );
});

class ProfilePreferencesRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  ProfilePreferencesRepository(this._dio, this._storage);

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

  Future<void> saveOnboardingPreferences({
    required List<String> activityTags,
    required List<String> dietaryPreferences,
    double maxBudget = 2500.0,
    String passengerType = 'Regular',
    List<String> accessibilityPreferences = const [],
  }) async {
    final token = await _storage.getOnboardingToken();

    if (token == null || token.trim().isEmpty) {
      throw StateError('Onboarding token is missing.');
    }

    try {
      await _dio.post(
        '${ApiEndpoints.apiPrefix}/profile/onboarding-preferences',
        data: {
          'activity_tags': activityTags,
          'dietary_preferences': dietaryPreferences,
          'max_budget': maxBudget,
          'passenger_type': passengerType,
          'accessibility_preferences': accessibilityPreferences,
        },
        options: Options(headers: {'X-Onboarding-Token': token}),
      );
    } on DioException catch (e) {
      print('=== ONBOARDING PREFERENCES ERROR ===');
      print('STATUS: ${e.response?.statusCode}');
      print('RESPONSE: ${e.response?.data}');
      print('REQUEST URL: ${e.requestOptions.uri}');
      print('====================================');
      rethrow;
    }
  }

  Future<void> saveTripPreferences({
    required String tripId,
    required List<String> activityTags,
    required List<String> dietaryPreferences,
    double maxBudget = 2500.0,
    int? desiredPlacesPerDay,
    List<String> accessibilityPreferences = const [],
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.apiPrefix}/trips/$tripId/member-preferences',
        data: {
          'activity_tags': activityTags,
          'dietary_preferences': dietaryPreferences,
          'max_budget': maxBudget,
          'desired_places_per_day': desiredPlacesPerDay,
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
