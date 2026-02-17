class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumArtUrl;
  final String previewUrl;
  final int durationMs;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtUrl,
    required this.previewUrl,
    required this.durationMs,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['trackId'].toString(),
      title: json['trackName'] ?? 'Unknown Title',
      artist: json['artistName'] ?? 'Unknown Artist',
      album: json['collectionName'] ?? 'Unknown Album',
      albumArtUrl: json['artworkUrl100']?.replaceAll('100x100', '600x600') ?? '',
      previewUrl: json['previewUrl'] ?? '',
      durationMs: json['trackTimeMillis'] ?? 0,
    );
  }

  Map<String, String> toMetadata() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtUrl': albumArtUrl,
      'previewUrl': previewUrl,
    };
  }
}
