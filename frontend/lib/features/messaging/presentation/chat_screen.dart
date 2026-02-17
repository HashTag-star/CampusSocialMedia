import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/messaging/presentation/message_provider.dart';
import 'package:campus_social_media/features/messaging/data/message_repository.dart';
import 'package:campus_social_media/features/messaging/domain/message.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:intl/intl.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _localMessages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark as read when opening
    Future.microtask(() {
      ref.read(messageRepositoryProvider).markAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    final msg = await ref.read(chatControllerProvider.notifier).sendMessage(
      widget.conversationId,
      content,
    );

    if (msg != null && mounted) {
      setState(() {
        _localMessages.add(msg);
        _isSending = false;
      });
      _scrollToBottom();
    } else if (mounted) {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                widget.otherUserName[0].toUpperCase(),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherUserName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined, size: 26), onPressed: () {}),
          IconButton(icon: const Icon(Icons.info_outline, size: 24), onPressed: () {}),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (serverMessages) {
                // Merge server messages with local (optimistic) messages
                final serverIds = serverMessages.map((m) => m.id).toSet();
                final allMessages = [
                  ...serverMessages,
                  ..._localMessages.where((m) => !serverIds.contains(m.id)),
                ];

                if (allMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: theme.hintColor),
                        const SizedBox(height: 12),
                        Text(
                          'Say hi to ${widget.otherUserName}! 👋',
                          style: TextStyle(color: theme.hintColor, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    final msg = allMessages[index];
                    final isMe = msg.senderId == currentUser?.id;
                    final showDate = index == 0 ||
                        !_isSameDay(allMessages[index - 1].createdAt, msg.createdAt);

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _formatDate(msg.createdAt),
                              style: TextStyle(color: theme.hintColor, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          isDark: isDark,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input Bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
            ),
            padding: EdgeInsets.only(
              left: 8, right: 8, top: 8,
              bottom: MediaQuery.of(context).viewPadding.bottom + 8,
            ),
            child: Row(
              children: [
                // Camera
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3897F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),

                // Text Input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Message...',
                              hintStyle: TextStyle(color: theme.hintColor),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            style: const TextStyle(fontSize: 15),
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.emoji_emotions_outlined, color: theme.hintColor, size: 24),
                          onPressed: () {},
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send
                GestureDetector(
                  onTap: _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _isSending ? Colors.grey : const Color(0xFF3897F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('MMM d, y').format(date);
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({required this.message, required this.isMe, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF3897F0)
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[100]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('h:mm a').format(message.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white60 : (isDark ? Colors.white38 : Colors.grey),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
