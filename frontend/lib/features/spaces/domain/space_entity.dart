import 'package:campus_social_media/features/feed/domain/post_entity.dart';
import 'package:campus_social_media/features/auth/domain/user.dart';

class Space {
  final String id;
  final String title;
  final String topic;
  final bool isActive;
  final int participantsCount;
  final User? host;

  Space({
    required this.id,
    required this.title,
    required this.topic,
    required this.isActive,
    this.participantsCount = 0,
    this.host,
  });

  factory Space.fromJson(Map<String, dynamic> json) {
    return Space(
      id: json['id'],
      title: json['title'],
      topic: json['topic'],
      isActive: json['is_active'] ?? false,
      participantsCount: json['participants_count'] ?? 0,
      host: json['Host'] != null ? User.fromJson(json['Host']) : null,
    );
  }
}
