import 'package:flutter/foundation.dart';

/// Backend locations.
///
/// Set TARALETS_API_BASE_URL with --dart-define for a physical device or a
/// backend hosted somewhere other than the local development machine.
class ApiEndpoints {
  ApiEndpoints._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'TARALETS_API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _configuredBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android emulators reach the host machine through this special alias.
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static const String apiPrefix = '/api/v1';

  static const String login = '$apiPrefix/auth/login';
  static const String register = '$apiPrefix/auth/register';
  static const String me = '$apiPrefix/auth/me';
}
