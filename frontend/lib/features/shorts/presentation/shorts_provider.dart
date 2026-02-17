import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/network/api_client.dart';
import 'package:campus_social_media/features/feed/domain/post_entity.dart';

final shortsProvider = FutureProvider<List<Post>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/posts/shorts');
  return (response.data as List).map((json) => Post.fromJson(json)).toList();
});
