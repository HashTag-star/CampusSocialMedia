enum MessageStatus { sending, sent, delivered, read, error }

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? mediaUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? sender;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.mediaUrl,
    required this.createdAt,
    this.sender,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'] ?? '',
      mediaUrl: json['media_url'],
      createdAt: DateTime.parse(json['createdAt']),
      sender: json['Sender'] as Map<String, dynamic>?,
      status: MessageStatus.sent, // Default to sent for server messages
    );
  }

  ChatMessage copyWith({
    String? id,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      mediaUrl: mediaUrl,
      createdAt: createdAt,
      sender: sender,
      status: status ?? this.status,
    );
  }

  String get senderName {
    final name = sender?['profile_data']?['name'];
    if (name != null && name.toString().isNotEmpty) return name;
    final email = sender?['email'] as String?;
    return email?.split('@')[0] ?? 'User';
  }
}
