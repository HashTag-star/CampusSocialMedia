import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/network/api_client.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository(ref.watch(apiClientProvider));
});

class StoryRepository {
  final Dio _dio;

  StoryRepository(this._dio);

  Future<void> viewStory(String storyId) async {
    try {
      await _dio.post('/stories/$storyId/view');
    } catch (e) {
      // Ignore errors for views (fire and forget)
    }
  }

  Future<void> interactStory({
    required String storyId,
    bool? liked,
    String? reaction,
    String? reply,
  }) async {
    await _dio.post('/stories/$storyId/interact', data: {
      if (liked != null) 'liked': liked,
      if (reaction != null) 'reaction': reaction,
      if (reply != null) 'reply': reply,
    });
  }

  Future<List<dynamic>> getStoryViewers(String storyId) async {
    final response = await _dio.get('/stories/$storyId/viewers');
    return response.data as List;
  }
}
