import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_endpoints.dart';
import '../services/secure_storage_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final storage = ref.read(secureStorageProvider);

        final token = await storage.getToken();

        if (token != null && token.trim().isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${token.trim()}';
        }

        if (kDebugMode) {
          debugPrint('Request: ${options.method} ${options.uri.path}');
          debugPrint(
            'Authorization header attached: '
            '${options.headers.containsKey('Authorization')}',
          );
          debugPrint(
            'Stored token exists: ${token != null && token.trim().isNotEmpty}',
          );
        }

        handler.next(options);
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  return dio;
});
