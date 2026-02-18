import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/network/api_client.dart';
import 'package:campus_social_media/features/spaces/domain/space_entity.dart';
import 'package:campus_social_media/core/services/cache_service.dart';

final spacesRepositoryProvider = Provider<SpacesRepository>((ref) {
  return SpacesRepository(ref.watch(apiClientProvider), ref.watch(cacheServiceProvider));
});

class SpacesRepository {
  final Dio _dio;
  final CacheService _cacheService;

  SpacesRepository(this._dio, this._cacheService);

  Future<List<Space>> getSpaces() async {
    try {
      final response = await _dio.get('/spaces');
      final list = response.data as List;
      await _cacheService.save('spaces_list', list);
      return list.map((e) => Space.fromJson(e)).toList();
    } catch (e) {
      final cached = await _cacheService.get('spaces_list');
      if (cached != null) {
         return (cached as List).map((e) => Space.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  Future<Space> createSpace(String title, String topic) async {
    try {
      final response = await _dio.post('/spaces', data: {
        'title': title,
        'topic': topic,
      });
      return Space.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinSpace(String spaceId) async {
    try {
      final response = await _dio.post('/spaces/$spaceId/join');
      return response.data; // Returns { token, space, connection_details }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> endSpace(String spaceId) async {
    await _dio.post('/spaces/$spaceId/end');
  }
}
