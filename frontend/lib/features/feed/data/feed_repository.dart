import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/network/api_client.dart';
import 'package:campus_social_media/features/feed/domain/post_entity.dart';
import 'package:campus_social_media/core/services/cache_service.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(apiClientProvider), ref.watch(cacheServiceProvider));
});

class FeedRepository {
  final Dio _dio;
  final CacheService _cacheService;

  FeedRepository(this._dio, this._cacheService);

  Future<List<Post>> getCampusFeed() async {
    try {
      final response = await _dio.get('/posts/feed/campus');
      final list = response.data as List;
      // Cache the response
      await _cacheService.save('campus_feed', list);
      return list.map((e) => Post.fromJson(e)).toList();
    } catch (e) {
      // Fallback to cache
      final cachedList = await _cacheService.get('campus_feed');
      if (cachedList != null) {
        return (cachedList as List).map((e) => Post.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  Future<List<Post>> getForYouFeed({String? cursor, String direction = 'older'}) async {
    try {
      final response = await _dio.get('/posts/feed/foryou', queryParameters: {
         if (cursor != null) 'cursor': cursor,
         'direction': direction,
         'limit': 20,
      });
      final list = response.data as List;
      
      // Only cache the first page (refresh)
      if (cursor == null) {
         await _cacheService.save('foryou_feed', list);
      }
      
      return list.map((e) => Post.fromJson(e)).toList();
    } catch (e) {
      // Fallback to cache only if it's a refresh (first page)
      if (cursor == null) {
        final cachedList = await _cacheService.get('foryou_feed');
        if (cachedList != null) {
          return (cachedList as List).map((e) => Post.fromJson(e)).toList();
        }
        // If no cache, try campus feed cache as last resort? Maybe not.
        try {
           return await getCampusFeed(); // Fallback logic from before
        } catch (_) {
           rethrow; 
        }
      }
      return [];
    }
  }

  Future<void> likePost(String postId) async {
    await _dio.post('/posts/$postId/like');
  }

  Future<void> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) async {
    await _dio.post('/interactions/report', data: {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'description': description,
    });
  }
  
  Future<void> createPost(
    String caption,
    List<String> mediaPaths, {
    String? location,
    List<String>? taggedUsers,
    Map<String, String>? musicMetadata,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'caption': caption,
        if (location != null) 'location': location,
        if (taggedUsers != null) 'tagged_users': jsonEncode(taggedUsers),
        if (musicMetadata != null) 'music_metadata': jsonEncode(musicMetadata),
      });

      for (final path in mediaPaths) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(path),
        ));
      }

      await _dio.post('/posts', data: formData);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getComments(String postId) async {
    try {
      final response = await _dio.get('/posts/$postId/comments');
      return response.data as List;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addComment(String postId, String content, {String? parentId}) async {
    try {
      await _dio.post('/posts/$postId/comments', data: {
        'content': content,
        if (parentId != null) 'parentId': parentId,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleCommentLike(String commentId) async {
    await _dio.post('/comments/$commentId/like');
  }

  Future<List<dynamic>> getStories() async {
    try {
      final response = await _dio.get('/stories');
       return response.data as List;
    } catch (e) {
      return [];
    }
  }

  Future<void> createStory(String imagePath, {String? caption, Map<String, String>? musicMetadata}) async {
    try {
      FormData formData = FormData.fromMap({
        if (caption != null) 'caption': caption,
        if (musicMetadata != null) 'music_metadata': jsonEncode(musicMetadata),
        'file': await MultipartFile.fromFile(imagePath),
      });
      await _dio.post('/stories', data: formData);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Post>> searchPosts(String query) async {
    try {
      final response = await _dio.get('/search', queryParameters: {'q': query});
      return (response.data as List).map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getPost(String postId) async {
    final response = await _dio.get('/posts/$postId');
    return response.data;
  }

  Future<void> deletePost(String postId) async {
    await _dio.delete('/posts/$postId');
  }

  Future<void> updatePostCaption(String postId, String caption) async {
    await _dio.patch('/posts/$postId', data: {'caption': caption});
  }

  Future<void> recordPostView(String postId, {int timeSpentMs = 0}) async {
    try {
      await _dio.post('/posts/$postId/view', data: {'timeSpentMs': timeSpentMs});
    } catch (_) {
      // Ignore view tracking errors
    }
  }
}
