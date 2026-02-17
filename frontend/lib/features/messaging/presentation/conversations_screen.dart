import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/messaging/presentation/message_provider.dart';
import 'package:campus_social_media/features/messaging/domain/conversation.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:campus_social_media/core/services/socket_service.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() async {
    final socketService = ref.read(socketServiceProvider);
    
    await socketService.initSocket();

    // Listen for any new message to refresh the list (unread counts, last message)
    socketService.onNewMessage((data) {
      if (mounted) {
        ref.invalidate(conversationsProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, size: 24),
            onPressed: () => context.push('/messages/new'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.hintColor),
              const SizedBox(height: 12),
              Text('Could not load messages', style: TextStyle(color: theme.hintColor)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => ref.invalidate(conversationsProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.onSurface, width: 2),
                    ),
                    child: Icon(Icons.send_rounded, size: 48, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 20),
                  Text('Your Messages', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Send a message to get the conversation started.',
                    style: TextStyle(color: theme.hintColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.push('/messages/new'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3897F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Send Message', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              itemBuilder: (context, index) => _ConversationTile(
                conversation: conversations[index],
                isDark: isDark,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isDark;

  const _ConversationTile({required this.conversation, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => context.push('/messages/chat/${conversation.id}', extra: {
        'otherUserName': conversation.otherUserName,
        'otherUserId': conversation.otherUserId,
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: conversation.otherUserAvatar != null
                      ? NetworkImage(conversation.otherUserAvatar!)
                      : null,
                  child: conversation.otherUserAvatar == null
                      ? Text(
                          conversation.otherUserName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3897F0),
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          conversation.unreadCount > 9 ? '9+' : '${conversation.unreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Name + Preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.otherUserName,
                    style: TextStyle(
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessageText ?? 'No messages yet',
                          style: TextStyle(
                            color: hasUnread ? theme.colorScheme.onSurface : theme.hintColor,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null) ...[
                        Text(' · ', style: TextStyle(color: theme.hintColor, fontSize: 13)),
                        Text(
                          timeago.format(conversation.lastMessageAt!, locale: 'en_short'),
                          style: TextStyle(color: theme.hintColor, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Camera icon
            IconButton(
              icon: Icon(Icons.camera_alt_outlined, color: theme.hintColor, size: 22),
              onPressed: () {},
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
