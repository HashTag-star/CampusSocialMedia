import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/network/api_client.dart';
import 'package:campus_social_media/features/feed/domain/post_entity.dart';
import 'package:campus_social_media/core/services/cache_service.dart';

final shortsProvider = FutureProvider<List<Post>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheServiceProvider);
  
  try {
    final response = await dio.get('/posts/shorts');
    final list = response.data as List;
    await cache.save('shorts_feed', list);
    return list.map((json) => Post.fromJson(json)).toList();
  } catch (e) {
    final cached = await cache.get('shorts_feed');
    if (cached != null) {
      return (cached as List).map((json) => Post.fromJson(json)).toList();
    }
    rethrow;
  }
});
