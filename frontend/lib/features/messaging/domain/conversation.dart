class Conversation {
  final String id;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final Map<String, dynamic>? otherUser;

  Conversation({
    required this.id,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.otherUser,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      lastMessageText: json['lastMessageText'],
      lastMessageAt: json['lastMessageAt'] != null ? DateTime.parse(json['lastMessageAt']) : null,
      unreadCount: json['unreadCount'] ?? 0,
      otherUser: json['otherUser'] as Map<String, dynamic>?,
    );
  }

  String get otherUserName {
    final name = otherUser?['profile_data']?['name'];
    if (name != null && name.toString().isNotEmpty) return name;
    final email = otherUser?['email'] as String?;
    return email?.split('@')[0] ?? 'User';
  }

  String? get otherUserAvatar => otherUser?['profile_data']?['avatar_url'];
  String get otherUserId => otherUser?['id'] ?? '';
}
