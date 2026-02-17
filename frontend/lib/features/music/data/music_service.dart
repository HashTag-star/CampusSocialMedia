import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/music/domain/music_track.dart';

final musicServiceProvider = Provider<MusicService>((ref) {
  return MusicService();
});

class MusicService {
  final Dio _dio = Dio();

  Future<List<MusicTrack>> searchMusic(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': query,
          'media': 'music',
          'entity': 'song',
          'limit': 20,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.data) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>;
        return results.map((json) => MusicTrack.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Music search error: $e');
      return [];
    }
  }
}
