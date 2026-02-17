import 'dart:convert';
import 'package:campus_social_media/features/auth/domain/user.dart';

class Post {
  final String id;
  final String userId;
  final User user;
  final String? caption;
  final String? mediaUrl;
  final String mediaType; // 'image', 'video', 'carousel', 'audio', 'none'
  final List<String> mediaUrls;
  final String? audioUrl;
  final Map<String, dynamic>? musicMetadata;
  final List<String> tags;
  final Map<String, dynamic>? location;
  final List<String> taggedUsers;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.userId,
    required this.user,
    this.caption,
    this.mediaUrl,
    required this.mediaType,
    this.mediaUrls = const [],
    this.audioUrl,
    this.musicMetadata,
    this.tags = const [],
    this.location,
    this.taggedUsers = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    required this.createdAt,
  });

  Post copyWith({
    String? caption,
    bool? isLikedByMe,
    int? likesCount,
    int? commentsCount,
  }) {
    return Post(
      id: id,
      userId: userId,
      user: user,
      caption: caption ?? this.caption,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      mediaUrls: mediaUrls,
      audioUrl: audioUrl,
      musicMetadata: musicMetadata,
      tags: tags,
      location: location,
      taggedUsers: taggedUsers,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      createdAt: createdAt,
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      userId: json['user_id'],
      user: User.fromJson(json['User']),
      caption: json['caption'] ?? '',
      mediaUrl: json['media_url'],
      mediaType: _parseMediaType(json['media_type']),
      mediaUrls: (json['media_urls'] as List?)?.map((e) => e as String).toList() ?? [],
      audioUrl: json['audio_url'],
      musicMetadata: _parseJsonMap(json['music_metadata']),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      location: _parseJsonMap(json['location']),
      taggedUsers: _parseJsonList(json['tagged_users']),
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      isLikedByMe: json['isLikedByMe'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  static Map<String, dynamic>? _parseJsonMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      try {
        return jsonDecode(value) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<String> _parseJsonList(dynamic value) {
     if (value == null) return [];
     if (value is List) return List<String>.from(value);
     if (value is String) {
       try {
         final decoded = jsonDecode(value);
         if (decoded is List) return List<String>.from(decoded);
       } catch (_) {
         return [];
       }
     }
     return [];
  }

  static String _parseMediaType(String? type) {
    if (type == null) return 'none';
    return type;
  }
}
