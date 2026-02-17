import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/messaging/data/message_repository.dart';
import 'package:campus_social_media/features/messaging/domain/conversation.dart';
import 'package:campus_social_media/features/messaging/domain/message.dart';

// ── Conversations List ──
final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) async {
  return ref.watch(messageRepositoryProvider).getConversations();
});

// ── Messages for a specific conversation ──
final messagesProvider = FutureProvider.autoDispose.family<List<ChatMessage>, String>((ref, conversationId) async {
  return ref.watch(messageRepositoryProvider).getMessages(conversationId);
});

// ── Chat Controller ──
class ChatController extends StateNotifier<AsyncValue<void>> {
  final MessageRepository _repository;
  final Ref _ref;

  ChatController(this._repository, this._ref) : super(const AsyncData(null));

  Future<ChatMessage?> sendMessage(String conversationId, String content) async {
    state = const AsyncLoading();
    try {
      final message = await _repository.sendMessage(conversationId, content);
      // Refresh conversations and messages
      _ref.invalidate(conversationsProvider);
      _ref.invalidate(messagesProvider(conversationId));
      state = const AsyncData(null);
      return message;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<Conversation?> startConversation(String recipientId) async {
    state = const AsyncLoading();
    try {
      final conversation = await _repository.createConversation(recipientId);
      _ref.invalidate(conversationsProvider);
      state = const AsyncData(null);
      return conversation;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
  return ChatController(ref.watch(messageRepositoryProvider), ref);
});
