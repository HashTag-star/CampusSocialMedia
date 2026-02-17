import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:campus_social_media/features/feed/domain/post_entity.dart';
import 'package:campus_social_media/features/feed/presentation/feed_provider.dart';
import 'package:campus_social_media/features/feed/data/feed_repository.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/comment_bottom_sheet.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/share_bottom_sheet.dart';
import 'dart:async';
import 'package:campus_social_media/core/constants/api_constants.dart';

class ReelViewerScreen extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;
  final bool showBackButton;

  const ReelViewerScreen({
    super.key,
    required this.posts,
    this.initialIndex = 0,
    this.showBackButton = true,
  });

  @override
  State<ReelViewerScreen> createState() => _ReelViewerScreenState();
}

class _ReelViewerScreenState extends State<ReelViewerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // Immersive mode
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore system UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, 
        statusBarIconBrightness: Brightness.dark, // Assuming app is light mode by default, or handle dynamically
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Vertical PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.posts.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return _ReelPage(
                post: widget.posts[index],
                isActive: index == _currentIndex,
              );
            },
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (widget.showBackButton)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 48), // Spacer to balance title logic if needed, or just remove
                  const Spacer(),
                  const Text(
                    'Reels',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 26),
                    onPressed: () => context.push('/create-reel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────
// Individual Reel Page
// ───────────────────────────────────────────────
class _ReelPage extends ConsumerStatefulWidget {
  final Post post;
  final bool isActive;

  const _ReelPage({required this.post, required this.isActive});

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _initialized = false;
  bool _isPaused = false;
  bool _showHeart = false;
  bool _hasError = false;

  // View Tracking
  Timer? _viewTimer;
  bool _hasRecordedView = false;

  String get _videoUrl {
    final url = widget.post.mediaUrl ?? '';
    return url.startsWith('http') ? url : '${ApiConstants.baseUrl}$url';
  }

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _initVideo();
    _handleVisibilityChange(widget.isActive);
  }

  void _handleVisibilityChange(bool visible) {
      if (visible && !_hasRecordedView) {
          _viewTimer?.cancel();
          _viewTimer = Timer(const Duration(seconds: 2), () {
              if (mounted && widget.isActive) {
                  ref.read(feedRepositoryProvider).recordPostView(widget.post.id, timeSpentMs: 2000);
                  _hasRecordedView = true;
              }
          });
      } else if (!visible) {
          _viewTimer?.cancel();
      }
  }

  void _initVideo() {
    _player.open(Media(_videoUrl), play: widget.isActive).then((_) {
       if (mounted) {
         setState(() => _initialized = true);
         _player.setPlaylistMode(PlaylistMode.loop);
         _player.setVolume(100.0); // 0-100
       }
    }).catchError((e) {
      debugPrint('Reel video error: $e');
      if (mounted) setState(() => _hasError = true);
    });
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
        _handleVisibilityChange(widget.isActive);
    }
    
    if (widget.isActive && !oldWidget.isActive) {
      _player.play();
      setState(() => _isPaused = false);
    } else if (!widget.isActive && oldWidget.isActive) {
      _player.pause();
    }
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;
    setState(() {
      if (_player.state.playing) {
        _player.pause();
        _isPaused = true;
      } else {
        _player.play();
        _isPaused = false;
      }
    });
  }

  void _doubleTapLike() {
    ref.read(feedNotifierProvider.notifier).toggleLike(widget.post.id);
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final username = widget.post.user.name ?? widget.post.user.email.split('@')[0];

    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: _doubleTapLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          if (_initialized)
            Center(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: screenSize.width,
                    height: screenSize.height,
                    child: Video(
                        controller: _controller,
                        fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            )
          else if (_hasError)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text('Failed to load video', style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),

          // Pause icon overlay
          if (_isPaused)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 56),
              ),
            ),

          // Double-tap heart animation
          if (_showHeart)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: const Icon(Icons.favorite, color: Colors.white, size: 100),
                  );
                },
              ),
            ),

          // Gradient overlay (bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenSize.height * 0.4,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // Right side actions
          Positioned(
            right: 12,
            bottom: 120,
            child: Column(
              children: [
                // Profile
                GestureDetector(
                  onTap: () => context.push('/profile/${widget.post.user.id}'),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: widget.post.user.avatarUrl != null
                              ? NetworkImage(widget.post.user.avatarUrl!)
                              : null,
                          child: widget.post.user.avatarUrl == null
                              ? Text(username[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                              : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3897F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Like
                _ReelAction(
                  icon: widget.post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                  label: '${widget.post.likesCount}',
                  color: widget.post.isLikedByMe ? Colors.red : Colors.white,
                  onTap: () => ref.read(feedNotifierProvider.notifier).toggleLike(widget.post.id),
                ),
                const SizedBox(height: 20),

                // Comment
                _ReelAction(
                  icon: Icons.chat_bubble_outline,
                  label: '${widget.post.commentsCount}',
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => CommentBottomSheet(postId: widget.post.id),
                  ),
                ),
                const SizedBox(height: 20),

                // Share
                _ReelAction(
                  icon: Icons.send_rounded,
                  label: 'Share',
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ShareBottomSheet(postId: widget.post.id),
                  ),
                ),
                const SizedBox(height: 20),

                // More
                _ReelAction(
                  icon: Icons.more_vert,
                  label: '',
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Bottom info
          Positioned(
            left: 12,
            right: 72,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username
                GestureDetector(
                  onTap: () => context.push('/profile/${widget.post.user.id}'),
                  child: Text(
                    username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Caption
                if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
                  Text(
                    widget.post.caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 10),

                // Music ticker
                if (widget.post.musicMetadata != null)
                  Row(
                    children: [
                      const Icon(Icons.music_note, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${widget.post.musicMetadata!['title']} • ${widget.post.musicMetadata!['artist']}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.music_note, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '$username • Original audio',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
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
}

// ───────────────────────────────────────────────
// Reel Action Button
// ───────────────────────────────────────────────
class _ReelAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ReelAction({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}
