/// Backend locations.
///
/// 10.0.2.2 is the Android emulator's alias for your computer's localhost,
/// so the FastAPI server running on port 8000 is reachable from the emulator.
/// On a physical device, replace it with your computer's LAN IP
/// (e.g. http://192.168.1.20:8000).
class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String apiPrefix = '/api/v1';

  static const String login = '$apiPrefix/auth/login';
  static const String register = '$apiPrefix/auth/register';
  static const String me = '$apiPrefix/auth/me';
}
