import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _onboardingTokenKey = 'onboarding_token';

  // Normal login token
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // Temporary token after OTP verification
  Future<void> saveOnboardingToken(String token) async {
    await _storage.write(key: _onboardingTokenKey, value: token);
  }

  Future<String?> getOnboardingToken() async {
    return _storage.read(key: _onboardingTokenKey);
  }

  Future<void> deleteOnboardingToken() async {
    await _storage.delete(key: _onboardingTokenKey);
  }
}
