import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/messaging/presentation/message_provider.dart';
import 'package:campus_social_media/features/messaging/data/message_repository.dart';
import 'package:campus_social_media/features/messaging/domain/message.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:campus_social_media/core/services/socket_service.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
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

  bool _isTyping = false;
  Timer? _typingDebounce;
  bool _otherUserIsTyping = false;
  final _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;
  Timer? _typingIndicatorTimer;
  DateTime? _otherUserLastReadAt;

  @override
  void initState() {
    super.initState();
    _initSocket();
    
    // Mark as read when opening
    Future.microtask(() {
      ref.read(messageRepositoryProvider).markAsRead(widget.conversationId);
    });
  }

  void _initSocket() {
    final socketService = ref.read(socketServiceProvider);
    socketService.joinConversation(widget.conversationId);

    socketService.onNewMessage((data) {
      if (mounted) {
        final message = ChatMessage.fromJson(data);
        if (!_localMessages.any((m) => m.id == message.id)) {
          setState(() {
            _localMessages.add(message);
            // If we receive a message, they clearly stopped typing
            _otherUserIsTyping = false; 
          });
          _scrollToBottom();
          ref.read(messageRepositoryProvider).markAsRead(widget.conversationId);
        }
      }
    });

    socketService.onTyping((data) {
      if (mounted && data['userId'] != ref.read(currentUserProvider)?.id) {
        setState(() => _otherUserIsTyping = true);
        
        // Auto-hide after 3 seconds if no stop_typing event comes
        _typingIndicatorTimer?.cancel();
        _typingIndicatorTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _otherUserIsTyping = false);
        });
      }
    });
    
    socketService.onStopTyping((data) {
       if (mounted && data['userId'] != ref.read(currentUserProvider)?.id) {
          setState(() => _otherUserIsTyping = false);
       }
    });

    socketService.on('message_read', (data) {
      if (mounted && data['conversationId'] == widget.conversationId) {
        // If the other user read it
        if (data['userId'] == widget.otherUserId) {
           setState(() {
             _otherUserLastReadAt = DateTime.now(); // Or parse data['readAt'] if reliable
           });
        }
      }
    });
  }

  void _onTextChanged(String text) {
    final socketService = ref.read(socketServiceProvider);
    
    if (!_isTyping && text.isNotEmpty) {
      _isTyping = true;
      socketService.sendTyping(widget.conversationId);
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      socketService.sendStopTyping(widget.conversationId);
    });
  }

  @override
  void dispose() {
    final socketService = ref.read(socketServiceProvider);
    socketService.off('new_message');
    socketService.off('typing');
    socketService.off('stop_typing');
    
    _typingDebounce?.cancel();
    _typingIndicatorTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;
    
    setState(() => _selectedImage = File(picked.path));
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    final image = _selectedImage;
    
    if ((content.isEmpty && image == null) || _isSending) return;

    // Stop typing immediately
    _typingDebounce?.cancel();
    ref.read(socketServiceProvider).sendStopTyping(widget.conversationId);
    _isTyping = false;

    // 1. Create Optimistic Message
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final currentUser = ref.read(currentUserProvider);
    final optimisticMsg = ChatMessage(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: currentUser?.id ?? '',
      content: content,
      mediaUrl: image?.path, // Use local path for preview
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      sender: currentUser?.toJson(),
    );

    setState(() {
      _localMessages.add(optimisticMsg);
      _messageController.clear();
      _selectedImage = null;
      // Don't set _isSending = true because we want to allow sending multiple messages
      // But we might want to throttle slightly or queue them. 
      // For now, let's keep it simple.
    });
    _scrollToBottom();

    try {
      String? mediaUrl;
      if (image != null) {
        // Upload Component
        // In a real app, we might want to show upload progress on the bubble itself
        mediaUrl = await ref.read(messageRepositoryProvider).uploadMedia(image);
      }

      final msg = await ref.read(chatControllerProvider.notifier).sendMessage(
        widget.conversationId,
        content,
        mediaUrl: mediaUrl,
      );

      if (msg != null && mounted) {
        setState(() {
           // Replace optimistic message with real one
           final index = _localMessages.indexWhere((m) => m.id == tempId);
           if (index != -1) {
             _localMessages[index] = msg;
           } else {
             _localMessages.add(msg);
           }
        });
      }
    } catch (e) {
      if (mounted) {
         setState(() {
           // Mark as error
           final index = _localMessages.indexWhere((m) => m.id == tempId);
           if (index != -1) {
             _localMessages[index] = _localMessages[index].copyWith(status: MessageStatus.error);
           }
         });
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
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
                    var msg = allMessages[index];
                    
                    // Check if message should be marked as read based on timestamp
                    if (msg.status != MessageStatus.read && 
                        _otherUserLastReadAt != null && 
                        msg.createdAt.isBefore(_otherUserLastReadAt!) &&
                        msg.senderId == currentUser?.id) {
                      msg = msg.copyWith(status: MessageStatus.read);
                    }

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
            child: Column(
              children: [
                 if (_selectedImage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 100,
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_selectedImage!, height: 100, width: 100, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                            if (_isUploading)
                               const Positioned.fill(
                                 child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                               ),
                          ],
                        ),
                      ],
                    ),
                  ),

                Row(
                  children: [
                    // Camera
                    GestureDetector( // Use GestureDetector for better touch target
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3897F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
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
                            IconButton(
                              icon: Icon(Icons.photo_library_outlined, color: theme.hintColor, size: 24),
                              onPressed: () => _pickImage(ImageSource.gallery),
                              visualDensity: VisualDensity.compact,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                onChanged: _onTextChanged,
                                decoration: InputDecoration(
                                  hintText: 'Message...',
                                  hintStyle: TextStyle(color: theme.hintColor),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                                style: const TextStyle(fontSize: 15),
                                textCapitalization: TextCapitalization.sentences,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            if (_selectedImage == null) // Hide emoji if image selected to save space? Nah keep it used for text
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
                          color: (_messageController.text.isNotEmpty || _selectedImage != null) 
                            ? const Color(0xFF3897F0) 
                            : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
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
            if (message.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: message.mediaUrl!.startsWith('http') 
                  ? CachedNetworkImage(
                      imageUrl: message.mediaUrl!,
                      placeholder: (context, url) => Container(
                        height: 150,
                        width: 200,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(message.mediaUrl!),
                      height: 150,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                ),
              ),
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(message.createdAt),
                  style: TextStyle(
                    color: isMe ? Colors.white60 : (isDark ? Colors.white38 : Colors.grey),
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  if (message.status == MessageStatus.sending)
                    const SizedBox(
                      width: 12, 
                      height: 12, 
                      child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white60)
                    )
                  else if (message.status == MessageStatus.error)
                     const Icon(Icons.error_outline, size: 14, color: Colors.redAccent)
                  else
                    Icon(
                      message.status == MessageStatus.read ? Icons.done_all : Icons.done,
                      size: 14,
                      color: message.status == MessageStatus.read ? Colors.blue[100] : Colors.white60,
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
