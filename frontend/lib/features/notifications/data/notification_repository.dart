import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/network/api_client.dart';
import 'package:campus_social_media/features/auth/domain/user.dart';

// Notification Model (Simplified for frontend)
class AppNotification {
  final String id;
  final String type; // 'follow', 'like', 'comment', 'suggestion'
  final String? message;
  final bool isRead;
  final User? actor;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    this.message,
    required this.isRead,
    this.actor,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      type: json['type'],
      message: json['message'],
      isRead: json['is_read'] ?? false,
      actor: json['Actor'] != null ? User.fromJson(json['Actor']) : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

class NotificationRepository {
  final Dio _dio;

  NotificationRepository(this._dio);

  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await _dio.get('/notifications');
      final list = response.data as List;
      return list.map((e) => AppNotification.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.patch('/notifications/read-all');
  }
}

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getNotifications();
});
