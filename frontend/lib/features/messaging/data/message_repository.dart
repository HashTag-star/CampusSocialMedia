import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/network/api_client.dart';
import 'package:campus_social_media/features/messaging/domain/conversation.dart';
import 'package:campus_social_media/features/messaging/domain/message.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(apiClientProvider));
});

class MessageRepository {
  final Dio _dio;

  MessageRepository(this._dio);

  Future<List<Conversation>> getConversations() async {
    final response = await _dio.get('/messages/conversations');
    return (response.data as List).map((json) => Conversation.fromJson(json)).toList();
  }

  Future<List<ChatMessage>> getMessages(String conversationId, {String? before}) async {
    final queryParams = <String, dynamic>{};
    if (before != null) queryParams['before'] = before;
    
    final response = await _dio.get(
      '/messages/conversations/$conversationId/messages',
      queryParameters: queryParams,
    );
    return (response.data as List).map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<Conversation> createConversation(String recipientId) async {
    final response = await _dio.post('/messages/conversations', data: {
      'recipientId': recipientId,
    });
    return Conversation.fromJson(response.data);
  }

  Future<ChatMessage> sendMessage(String conversationId, String? content, {String? mediaUrl}) async {
    final response = await _dio.post(
      '/messages/conversations/$conversationId/messages',
      data: {
        'content': content, 
        'media_url': mediaUrl
      },
    );
    return ChatMessage.fromJson(response.data);
  }

  Future<String?> uploadMedia(File file) async {
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post('/messages/upload', data: formData);
      return response.data['url'];
    } catch (e) {
      // Return null or rethrow based on preference
      return null;
    }
  }

  Future<void> markAsRead(String conversationId) async {
    await _dio.patch('/messages/conversations/$conversationId/read');
  }
}
