import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:campus_social_media/core/constants/api_constants.dart';
import 'package:campus_social_media/features/feed/data/feed_repository.dart';
import 'package:campus_social_media/features/feed/presentation/feed_provider.dart';
import 'package:campus_social_media/features/profile/presentation/profile_provider.dart';
import 'package:campus_social_media/features/post/presentation/widgets/comment_skeleton.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:flutter/services.dart';

// Provider for comments of a specific post
final postCommentsProvider = FutureProvider.family<List<dynamic>, String>((ref, postId) async {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.getComments(postId);
});

class PostDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;
  final bool isOwner;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.isOwner = false,
  });

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  late Map<String, dynamic> _post;
  bool _isEditing = false;
  late TextEditingController _captionController;
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  String? _replyingToId; // ID of the comment being replied to
  String? _replyingToName; // Name of the user being replied to
  String get _baseUrl => ApiConstants.baseUrl;

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
    _captionController = TextEditingController(text: _post['caption'] ?? '');
  }

  @override
  void dispose() {
    _captionController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(feedRepositoryProvider).deletePost(_post['id']);
      if (mounted) {
        ref.invalidate(profileProvider('me'));
        ref.invalidate(feedNotifierProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _saveCaption() async {
    try {
      await ref.read(feedRepositoryProvider).updatePostCaption(
        _post['id'],
        _captionController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _post['caption'] = _captionController.text.trim();
          _isEditing = false;
        });
        ref.invalidate(profileProvider('me'));
        ref.invalidate(feedNotifierProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caption updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      await ref.read(feedRepositoryProvider).addComment(
        _post['id'],
        content,
        parentId: _replyingToId,
      );
      _commentController.clear();
      setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });
      FocusScope.of(context).unfocus();
      ref.invalidate(postCommentsProvider(_post['id']));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    try {
      await ref.read(feedRepositoryProvider).toggleCommentLike(commentId);
      ref.invalidate(postCommentsProvider(_post['id']));
    } catch (e) {
      // Optimistic update failed, revert? For now, just show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to like comment: $e')),
        );
      }
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
    final isDark = theme.brightness == Brightness.dark;
    final mediaUrl = _post['media_url'] as String?;
    final caption = _post['caption'] as String? ?? '';
    final createdAt = _post['createdAt'] != null ? DateTime.tryParse(_post['createdAt']) : null;
    final user = _post['User'] as Map<String, dynamic>?;
    final profileData = user?['profile_data'] as Map<String, dynamic>? ?? {};
    final avatarUrl = profileData['avatar_url'] as String?;
    final userName = profileData['name'] ?? user?['email']?.split('@')[0] ?? 'User';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: widget.isOwner
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      setState(() => _isEditing = !_isEditing);
                    } else if (value == 'delete') {
                      _deletePost();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Caption')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                          child: avatarUrl == null ? Icon(Icons.person, size: 18, color: theme.colorScheme.onSurface) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              if (createdAt != null)
                                Text(timeago.format(createdAt), style: TextStyle(fontSize: 12, color: theme.hintColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Media
                  if (mediaUrl != null)
                    AspectRatio(
                      aspectRatio: 1,
                      child: CachedNetworkImage(
                        imageUrl: mediaUrl.startsWith('http') ? mediaUrl : '$_baseUrl$mediaUrl',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48)),
                      ),
                    ),

                  // Caption
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: _isEditing
                        ? Column(
                            children: [
                              TextField(
                                controller: _captionController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Write a caption...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _isEditing = false;
                                      _captionController.text = _post['caption'] ?? '';
                                    }),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(onPressed: _saveCaption, child: const Text('Save')),
                                ],
                              ),
                            ],
                          )
                        : caption.isNotEmpty
                            ? RichText(
                                text: TextSpan(
                                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                                  children: [
                                    TextSpan(text: '$userName  ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    TextSpan(text: caption),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),

                  const Divider(),

                  // Comments Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Comments', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: theme.colorScheme.onSurface)),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final commentsAsync = ref.watch(postCommentsProvider(_post['id']));
                      return commentsAsync.when(
                        data: (comments) {
                          if (comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(child: Text('No comments yet.', style: TextStyle(color: theme.hintColor))),
                            );
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return _buildCommentItem(comment, theme);
                            },
                          );
                        },
                        loading: () => const CommentSkeleton(),
                        error: (err, _) => Center(child: Text('Error loading comments', style: TextStyle(color: Colors.red))),
                      );
                    },
                  ),
                  const SizedBox(height: 80), // Space for input
                ],
              ),
            ),
          ),
          
          // Comment Input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_replyingToName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
                    // Current User Avatar
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
                            hintStyle: TextStyle(fontSize: 14, color: theme.hintColor),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF3897F0)),
                      onPressed: _addComment,
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

    return Column(
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
                      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                      children: [
                        TextSpan(text: '$name ', style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: timeago.format(createdAt, locale: 'en_short'), style: TextStyle(color: theme.hintColor, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(content, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _startReply(comment['id'], name),
                        child: Text('Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.hintColor)),
                      ),
                      const SizedBox(width: 16),
                      // Like Logic
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
        // Render Nested Replies
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 12),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: replies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildCommentItem(replies[index], theme);
              },
            ),
          ),
      ],
    );
  }
}
