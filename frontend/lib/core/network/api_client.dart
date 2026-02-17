import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:campus_social_media/core/constants/api_constants.dart';
import 'package:campus_social_media/core/services/error_service.dart';
import 'package:campus_social_media/core/services/storage_service.dart';



// Provider for Dio Client
final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final errorService = ref.watch(errorServiceProvider);
  
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.read(key: 'auth_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (DioException e, handler) {
      if (e.response?.statusCode != 401) {
          // 401 is usually handled by auth logic redirecting to login
          // But showing a toast is fine too
          errorService.handleDioError(e);
      }
      return handler.next(e);
    },
  ));

  return dio;
});
