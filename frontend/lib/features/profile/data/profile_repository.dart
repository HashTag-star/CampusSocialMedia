import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/network/api_client.dart';
import 'package:campus_social_media/features/auth/domain/user.dart';
import 'package:campus_social_media/core/services/cache_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider), ref.watch(cacheServiceProvider));
});

class ProfileRepository {
  final Dio _dio;
  final CacheService _cacheService;

  ProfileRepository(this._dio, this._cacheService);

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      await _cacheService.save('profile_$userId', response.data);
      return response.data;
    } catch (e) {
      final cached = await _cacheService.get('profile_$userId');
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get('/users/me');
      await _cacheService.save('profile_me', response.data);
      return response.data;
    } catch (e) {
      final cached = await _cacheService.get('profile_me');
      if (cached != null) return cached;
      rethrow;
    }
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
    try {
      final response = await _dio.get('/users/$userId/followers');
      final list = response.data as List;
      await _cacheService.save('followers_$userId', list);
      return list;
    } catch (e) {
      final cached = await _cacheService.get('followers_$userId');
      if (cached != null) return cached as List;
      rethrow;
    }
  }

  Future<List<dynamic>> getFollowing(String userId) async {
    try {
      final response = await _dio.get('/users/$userId/following');
      final list = response.data as List;
      await _cacheService.save('following_$userId', list);
      return list;
    } catch (e) {
      final cached = await _cacheService.get('following_$userId');
      if (cached != null) return cached as List;
      rethrow;
    }
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
