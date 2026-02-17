import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MusicRepository();
});

class MusicTrack {
  final String trackName;
  final String artistName;
  final String artworkUrl;
  final String previewUrl;
  final String collectionName;

  MusicTrack({
    required this.trackName,
    required this.artistName,
    required this.artworkUrl,
    required this.previewUrl,
    required this.collectionName,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      trackName: json['trackName'] ?? 'Unknown Track',
      artistName: json['artistName'] ?? 'Unknown Artist',
      artworkUrl: json['artworkUrl100'] ?? '',
      previewUrl: json['previewUrl'] ?? '',
      collectionName: json['collectionName'] ?? '',
    );
  }
}

class MusicRepository {
  final Dio _dio = Dio();

  Future<List<MusicTrack>> searchMusic(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': query,
          'entity': 'song',
          'limit': 20,
        },
      );

      if (response.statusCode == 200) {
        final results = response.data['results'] as List;
        return results.map((json) => MusicTrack.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      // print('Error searching music: $e');
      return [];
    }
  }
}
