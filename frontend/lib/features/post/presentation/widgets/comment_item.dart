import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter/services.dart';

class CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onShare;

  const CommentItem({
    super.key,
    required this.comment,
    required this.onReply,
    required this.onLike,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = comment['User'] as Map<String, dynamic>? ?? {};
    final profileData = user['profile_data'] as Map<String, dynamic>? ?? {};
    final avatarUrl = profileData['avatar_url'] as String?;
    final name = profileData['name'] ?? user['email']?.split('@')[0] ?? 'User';
    final content = comment['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(comment['createdAt'] ?? '') ?? DateTime.now();
    
    final likesCount = comment['likesCount'] as int? ?? 0;
    final isLiked = comment['isLikedByMe'] as bool? ?? false;
    final replies = comment['Replies'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
              child: avatarUrl == null
                  ? Icon(Icons.person, size: 18, color: theme.colorScheme.onSurface)
                  : null,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                      children: [
                        TextSpan(
                          text: '$name ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: timeago.format(createdAt, locale: 'en_short'),
                          style: TextStyle(color: theme.hintColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(content, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  // Actions Row
                  Row(
                    children: [
                      // Reply
                      GestureDetector(
                        onTap: onReply,
                        child: Text(
                          'Reply',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.hintColor),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Like
                      GestureDetector(
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: isLiked ? Colors.red : theme.hintColor,
                            ),
                            if (likesCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                likesCount.toString(),
                                style: TextStyle(fontSize: 12, color: theme.hintColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Share (Copy)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Comment copied to clipboard'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Icon(Icons.copy, size: 14, color: theme.hintColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // Nested Replies
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 12),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: replies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final reply = replies[index];
                return CommentItem(
                  comment: reply,
                  onReply: onReply, // Reply to parent
                  onLike: () {}, // TODO: Handle nested likes
                  onShare: () {},
                );
              },
            ),
          ),
      ],
    );
  }
}
