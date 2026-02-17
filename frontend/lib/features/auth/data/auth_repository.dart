import 'package:campus_social_media/features/auth/domain/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:campus_social_media/core/network/api_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<User> getMe() async {
    final response = await _dio.get('/auth/me');
    return User.fromJson(response.data);
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final token = response.data['token'];
      final user = User.fromJson(response.data['user']);
      return AuthResponse(token, user);
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> register(String email, String password, String domain) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'university_domain': domain
      });
      final token = response.data['token'];
      final user = User.fromJson(response.data['user']);
      return AuthResponse(token, user);
    } catch (e) {
      rethrow;
    }
  }
}

class AuthResponse {
  final String token;
  final User user;
  AuthResponse(this.token, this.user);
}
