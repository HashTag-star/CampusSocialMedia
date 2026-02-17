import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/feed/presentation/feed_provider.dart';
import 'package:campus_social_media/features/feed/data/feed_repository.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shimmer/shimmer.dart';

class CommentBottomSheet extends ConsumerStatefulWidget {
  final String postId;

  const CommentBottomSheet({super.key, required this.postId});

  @override
  ConsumerState<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends ConsumerState<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  
  List<dynamic> _comments = [];
  bool _isLoading = true;
  String? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await ref.read(feedRepositoryProvider).getComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    _commentController.clear();
    FocusScope.of(context).unfocus();

    try {
      await ref.read(feedRepositoryProvider).addComment(
        widget.postId, 
        content,
        parentId: _replyingToId,
      );
      
      // Reset reply state
      setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });

      await _loadComments(); // Refresh list to show new comment
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    try {
      await ref.read(feedRepositoryProvider).toggleCommentLike(commentId);
      _loadComments(); // Refresh to update like count/state
    } catch (e) {
      // Ignore or show error
    }
  }

  void _startReply(String commentId, String userName) {
    setState(() {
      _replyingToId = commentId;
      _replyingToName = userName;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
    _commentFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Text(
              'Comments', 
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
            ),
            const Divider(),
            
            // Comments List
            Expanded(
              child: _isLoading 
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: 6,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, __) => const _CommentSkeleton(),
                    ) 
                  : _comments.isEmpty 
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: theme.disabledColor),
                              const SizedBox(height: 12),
                              Text('No comments yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                              Text('Start the conversation.', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _comments.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            return _buildCommentItem(_comments[index], theme);
                          },
                        ),
            ),

            const Divider(height: 1),

            // Input Field
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingToName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 44),
                      child: Row(
                        children: [
                          Text('Replying to $_replyingToName', style: TextStyle(fontSize: 12, color: theme.hintColor)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _cancelReply,
                            child: Icon(Icons.close, size: 14, color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                       Consumer(builder: (context, ref, _) {
                        final user = ref.watch(currentUserProvider);
                        final avatarUrl = user?.avatarUrl;
                        return CircleAvatar(
                          radius: 18,
                          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          child: avatarUrl == null ? const Icon(Icons.person, size: 20) : null,
                        );
                      }),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            decoration: InputDecoration(
                              hintText: _replyingToName != null ? 'Reply...' : 'Add a comment...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: theme.hintColor),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            minLines: 1,
                            maxLines: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addComment,
                        icon: const Icon(Icons.send, color: Color(0xFF3897F0)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, ThemeData theme) {
    final user = comment['User'] as Map<String, dynamic>? ?? {};
    final profileData = user['profile_data'] as Map<String, dynamic>? ?? {};
    final avatarUrl = profileData['avatar_url'] as String?;
    final name = profileData['name'] ?? user['email']?.split('@')[0] ?? 'User';
    final content = comment['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(comment['createdAt'] ?? '') ?? DateTime.now();
    
    final likesCount = comment['likesCount'] as int? ?? 0;
    final isLiked = comment['isLikedByMe'] as bool? ?? false;
    final replies = comment['Replies'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl == null ? Icon(Icons.person, size: 18, color: theme.colorScheme.onSurface) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: '  '),
                          TextSpan(
                            text: timeago.format(createdAt, locale: 'en_short'),
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(content, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _startReply(comment['id'], name),
                          child: Text('Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.hintColor)),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _toggleCommentLike(comment['id']),
                          child: Row(
                            children: [
                              Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 14, color: isLiked ? Colors.red : theme.hintColor),
                              if (likesCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(likesCount.toString(), style: TextStyle(fontSize: 12, color: theme.hintColor)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                             Clipboard.setData(ClipboardData(text: content));
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(milliseconds: 800)));
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
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: replies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildCommentItem(replies[index], theme);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentSkeleton extends StatelessWidget {
  const _CommentSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 18, backgroundColor: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 120, 
                    height: 10, 
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                    ),
                ),
                const SizedBox(height: 8),
                Container(
                    width: double.infinity, 
                    height: 10, 
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                    ),
                ),
                const SizedBox(height: 4),
                Container(
                    width: 200, 
                    height: 10, 
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                    ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
