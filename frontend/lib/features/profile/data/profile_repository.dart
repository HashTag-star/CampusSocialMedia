import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/network/api_client.dart';
import 'package:campus_social_media/features/auth/domain/user.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

class ProfileRepository {
  final Dio _dio;

  ProfileRepository(this._dio);

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await _dio.get('/users/$userId');
    return response.data;
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _dio.get('/users/me');
    return response.data;
  }

  Future<void> followUser(String userId) async {
    await _dio.post('/users/$userId/follow');
  }

  Future<void> unfollowUser(String userId) async {
    await _dio.delete('/users/$userId/unfollow');
  }

  Future<void> blockUser(String userId) async {
    await _dio.post('/users/$userId/block');
  }

  Future<List<dynamic>> getFollowers(String userId) async {
    final response = await _dio.get('/users/$userId/followers');
    return response.data as List;
  }

  Future<List<dynamic>> getFollowing(String userId) async {
    final response = await _dio.get('/users/$userId/following');
    return response.data as List;
  }

  Future<void> updateProfile({
    String? name,
    String? bio,
    String? major,
    String? year,
    List<String>? interests,
  }) async {
    await _dio.patch('/users/me', data: {
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (major != null) 'major': major,
      if (year != null) 'year': year,
      if (interests != null) 'interests': interests,
    });
  }

  Future<List<User>> getSuggestedUsers() async {
    final response = await _dio.get('/users/suggestions/list');
    return (response.data as List).map((json) => User.fromJson(json)).toList();
  }

  Future<void> updateAvatar(String filePath) async {
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    await _dio.patch('/users/me/avatar', data: formData);
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final response = await _dio.get('/users/search', queryParameters: {'q': query});
    return response.data as List;
  }
}
