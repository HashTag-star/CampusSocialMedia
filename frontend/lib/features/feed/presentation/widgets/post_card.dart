import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/feed/domain/post_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:campus_social_media/features/feed/presentation/feed_provider.dart';
import 'package:campus_social_media/features/feed/data/feed_repository.dart';
import 'package:campus_social_media/features/feed/presentation/feed_audio_provider.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/comment_bottom_sheet.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/share_bottom_sheet.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/double_tap_heart.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs;
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/core/constants/api_constants.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:campus_social_media/features/profile/data/profile_repository.dart';
import 'package:campus_social_media/features/common/presentation/report_sheet.dart';
class PostCard extends ConsumerStatefulWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isVisible = false;
  
  // Header animation
  bool _showMusicInfo = false;
  Timer? _headerTimer;

  // View Tracking
  Timer? _viewTimer;
  bool _hasRecordedView = false;

  @override
  void initState() {
    super.initState();
    if (widget.post.musicMetadata != null && widget.post.location != null) {
        _startHeaderTimer();
    } else {
        // If only music is present, show music. If only location, show location.
        // If both, toggle.
        _showMusicInfo = widget.post.musicMetadata != null;
    }
  }

  void _startHeaderTimer() {
    _headerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() => _showMusicInfo = !_showMusicInfo);
      }
    });
  }

  @override
  void dispose() {
    _headerTimer?.cancel();
    _viewTimer?.cancel();
    super.dispose();
  }

  String get _baseUrl {
    return ApiConstants.baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = widget.post.user.name ?? widget.post.user.email.split('@')[0];
    final isLiked = widget.post.isLikedByMe;

    return VisibilityDetector(
      key: Key('post_${widget.post.id}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.6;
        if (_isVisible != visible && mounted) {
          setState(() => _isVisible = visible);
          
          if (visible && !_hasRecordedView) {
             _viewTimer?.cancel();
             _viewTimer = Timer(const Duration(seconds: 2), () {
                 if (mounted && _isVisible) {
                     ref.read(feedRepositoryProvider).recordPostView(widget.post.id, timeSpentMs: 2000);
                     _hasRecordedView = true;
                 }
             });
          } else if (!visible) {
              _viewTimer?.cancel();
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Avatar + Username + Menu)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile/${widget.post.user.id}'),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: widget.post.user.avatarUrl != null
                        ? CachedNetworkImageProvider(widget.post.user.avatarUrl!)
                        : null,
                    child: widget.post.user.avatarUrl == null
                        ? Icon(Icons.person, size: 16, color: theme.colorScheme.onSurface)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/profile/${widget.post.user.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Dynamic Subtitle (Location <-> Music)
                        AnimatedSwitcher(
                           duration: const Duration(milliseconds: 300),
                           child: _buildSubtitle(theme),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    if (value == 'block') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Block ${username}?'),
                          content: const Text('They will not be able to find your profile, posts, or story. Campus Social Media will not let them know you blocked them.'),
                          actions: [
                            TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => context.pop(true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Block')
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                          try {
                              await ref.read(profileRepositoryProvider).blockUser(widget.post.user.id);
                              if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Blocked $username')));
                                  // Remove this post and potentially others by same user from feed
                                  ref.read(feedNotifierProvider.notifier).removePost(widget.post.id);
                                  // In a real app we might want to iterate and remove ALL posts by this user from the current feed state,
                                  // but removing the current one is immediate feedback.
                              }
                          } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to block user')));
                          }
                      }
                    } else if (value == 'report') {
                        showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ReportSheet(
                                targetType: 'post',
                                targetId: widget.post.id,
                            ),
                        );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Report'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Block', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Media
          if (widget.post.mediaType == 'carousel' && widget.post.mediaUrls.isNotEmpty)
            _buildCarousel(context, ref, widget.post)
          else if (widget.post.mediaType == 'video' && widget.post.mediaUrl != null)
             Stack(
              children: [
                _VideoMediaWidget(
                  videoUrl: widget.post.mediaUrl!.startsWith('http') ? widget.post.mediaUrl! : '$_baseUrl${widget.post.mediaUrl}',
                  onDoubleTap: () => ref.read(feedNotifierProvider.notifier).toggleLike(widget.post.id),
                  isVisible: _isVisible,
                ),
                // Reel Icon
                Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                        onTap: () => context.push('/reel', extra: {
                            'posts': [widget.post],
                            'initialIndex': 0,
                        }),
                        child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 18),
                        ),
                    ),
                ),
              ],
             )
          else if (widget.post.mediaUrl != null)
            Builder(
              builder: (context) {
                final rawUrl = widget.post.mediaUrl!;
                final fullUrl = rawUrl.startsWith('http') ? rawUrl : '$_baseUrl$rawUrl';
                final lowerUrl = rawUrl.toLowerCase();
                final isVideo = widget.post.mediaType == 'video' ||
                              lowerUrl.endsWith('.mp4') || 
                              lowerUrl.endsWith('.mov') || 
                              lowerUrl.endsWith('.avi') ||
                              lowerUrl.endsWith('.webm') ||
                              lowerUrl.endsWith('.mkv') ||
                              lowerUrl.endsWith('.flv') ||
                              lowerUrl.endsWith('.wmv');

                if (isVideo) {
                  return Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.width * 0.52,
                        maxHeight: MediaQuery.of(context).size.width * 1.25,
                    ),
                    child: _VideoMediaWidget(
                      videoUrl: fullUrl,
                      onDoubleTap: () => ref.read(feedNotifierProvider.notifier).toggleLike(widget.post.id),
                      isVisible: _isVisible,
                    ),
                  );
                }

                return Stack(
                  children: [
                    DoubleTapHeart(
                      onDoubleTap: () => ref.read(feedNotifierProvider.notifier).toggleLike(widget.post.id),
                      child: GestureDetector(
                        onTap: () => ref.read(feedAudioProvider.notifier).toggleMute(),
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.width * 0.52,
                            maxHeight: MediaQuery.of(context).size.width * 1.25,
                          ),
                          color: theme.brightness == Brightness.dark ? Colors.black : const Color(0xFFF5F5F5),
                          child: CachedNetworkImage(
                            imageUrl: fullUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            placeholder: (context, url) => SizedBox(
                              height: MediaQuery.of(context).size.width,
                              child: Center(
                                child: Icon(Icons.image, color: theme.disabledColor),
                              ),
                            ),
                            errorWidget: (context, url, error) => SizedBox(
                              height: MediaQuery.of(context).size.width * 0.5,
                              child: Center(child: Icon(Icons.broken_image, color: theme.disabledColor)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Music Player Invisible Logic
                    if (widget.post.musicMetadata != null)
                       _MusicPlayerWidget(
                           metadata: widget.post.musicMetadata!,
                           isVisible: _isVisible,
                       ),
                    // Mute Icon Overlay (for music posts)
                    if (widget.post.musicMetadata != null)
                        Positioned(
                            bottom: 12,
                            right: 12,
                            child: Consumer(
                                builder: (context, ref, _) {
                                    final isMuted = ref.watch(feedAudioProvider);
                                    return Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Icon(
                                            isMuted ? Icons.volume_off : Icons.volume_up,
                                            color: Colors.white,
                                            size: 16,
                                        ),
                                    );
                                },
                            ),
                        ),
                  ],
                );
              }
            ),

          // 3. Action Bar (Heart, Comment, Share ... Bookmark)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => ref.read(feedNotifierProvider.notifier).toggleLike(widget.post.id),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(isLiked),
                      color: isLiked ? Colors.red : theme.colorScheme.onSurface,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => CommentBottomSheet(postId: widget.post.id),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, size: 26),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ShareBottomSheet(postId: widget.post.id),
                  ),
                  child: const Icon(Icons.send_rounded, size: 26),
                ),
                const Spacer(),
                const Icon(Icons.bookmark_border, size: 28),
              ],
            ),
          ),

          // 4. Likes & Caption & Comments
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.likesCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${widget.post.likesCount} likes',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (widget.post.caption != null)
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(text: widget.post.caption),
                      ],
                    ),
                  ),
                if (widget.post.commentsCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => CommentBottomSheet(postId: widget.post.id),
                  ),
                      child: Text(
                        'View all ${widget.post.commentsCount} comments',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    timeago.format(widget.post.createdAt, locale: 'en_short').toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
      if (_showMusicInfo && widget.post.musicMetadata != null) {
          final title = widget.post.musicMetadata!['title'] ?? 'Unknown';
          final artist = widget.post.musicMetadata!['artist'] ?? 'Unknown';
          return Row(
              key: const ValueKey('music'),
              children: [
                  Icon(Icons.music_note, size: 12, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 4),
                  Text(
                      '$title • $artist',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                  ),
              ],
          );
      } else if (widget.post.location != null && widget.post.location!['name'] != null) {
          return Padding(
              key: const ValueKey('location'),
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                  widget.post.location!['name'],
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
              ),
          );
      }
      return const SizedBox.shrink();
  }

  Widget _buildCarousel(BuildContext context, WidgetRef ref, Post post) {
    return _CarouselMediaWidget(
      post: post,
      baseUrl: _baseUrl,
      onDoubleTap: () => ref.read(feedNotifierProvider.notifier).toggleLike(post.id),
      isVisible: _isVisible,
    );
  }
}

// ──────────────────────────────────────────
// Carousel Widget with Dots + Counter
// ──────────────────────────────────────────
class _CarouselMediaWidget extends StatefulWidget {
  final Post post;
  final String baseUrl;
  final VoidCallback onDoubleTap;
  final bool isVisible;

  const _CarouselMediaWidget({
    required this.post,
    required this.baseUrl,
    required this.onDoubleTap,
    required this.isVisible,
  });

  @override
  State<_CarouselMediaWidget> createState() => _CarouselMediaWidgetState();
}

class _CarouselMediaWidgetState extends State<_CarouselMediaWidget> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final totalSlides = widget.post.mediaUrls.length;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Carousel
        cs.CarouselSlider(
          options: cs.CarouselOptions(
            height: MediaQuery.of(context).size.width,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() => _currentIndex = index);
            },
          ),
          items: widget.post.mediaUrls.map((url) {
            final fullUrl = url.startsWith('http') ? url : '${widget.baseUrl}$url';
            final lowerUrl = url.toLowerCase();
            final isVideo = lowerUrl.endsWith('.mp4') || 
                          lowerUrl.endsWith('.mov') || 
                          lowerUrl.endsWith('.avi') ||
                          lowerUrl.endsWith('.webm') ||
                          lowerUrl.endsWith('.mkv') ||
                          lowerUrl.endsWith('.flv') ||
                          lowerUrl.endsWith('.wmv');

            if (isVideo) {
               final index = widget.post.mediaUrls.indexOf(url);
               return Builder(
                builder: (context) => _VideoMediaWidget(
                  videoUrl: fullUrl,
                  onDoubleTap: widget.onDoubleTap,
                  isVisible: widget.isVisible && index == _currentIndex,
                ),
              );
            }

            return Builder(
              builder: (BuildContext context) {
                return DoubleTapHeart(
                  onDoubleTap: widget.onDoubleTap,
                  child: CachedNetworkImage(
                    imageUrl: fullUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.image)),
                    ),
                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
                  ),
                );
              },
            );
          }).toList(),
        ),

        // Slide counter badge (top-right)
        if (totalSlides > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${_currentIndex + 1}/$totalSlides',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        // Dot indicators (bottom-center)
        if (totalSlides > 1)
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalSlides, (index) {
                final isActive = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 8 : 6,
                  height: isActive ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                    boxShadow: isActive
                        ? [BoxShadow(color: Colors.black26, blurRadius: 2)]
                        : null,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// Video Player Widget for Feed (MediaKit)
// ──────────────────────────────────────────
class _VideoMediaWidget extends ConsumerStatefulWidget {
  final String videoUrl;
  final VoidCallback onDoubleTap;
  final bool isVisible;

  const _VideoMediaWidget({
    required this.videoUrl,
    required this.onDoubleTap,
    required this.isVisible,
  });

  @override
  ConsumerState<_VideoMediaWidget> createState() => _VideoMediaWidgetState();
}

class _VideoMediaWidgetState extends ConsumerState<_VideoMediaWidget> {
  late final Player _player;
  late final VideoController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    
    _player.open(Media(widget.videoUrl), play: false).then((_) {
       if (mounted) {
         setState(() => _initialized = true);
         _player.setPlaylistMode(PlaylistMode.loop);
         _player.setVolume(0); 
       }
    });
  }

  @override
  void didUpdateWidget(covariant _VideoMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized) {
        // Play/Pause based on visibility
        if (widget.isVisible && !oldWidget.isVisible) {
            _player.play();
        } else if (!widget.isVisible && oldWidget.isVisible) {
            _player.pause();
        }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
      // Toggle global mute instead of play/pause
      ref.read(feedAudioProvider.notifier).toggleMute();
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = ref.watch(feedAudioProvider);
    
    if (_initialized) {
        final targetVolume = isMuted ? 0.0 : 100.0;
        // MediaKit volume is 0-100, not 0.0-1.0
        if (_player.state.volume != targetVolume) {
            _player.setVolume(targetVolume);
        }
        
         // Auto-play checks
        if (widget.isVisible && !_player.state.playing) {
             _player.play();
        } else if (!widget.isVisible && _player.state.playing) {
             _player.pause();
        }
    }

    final screenW = MediaQuery.of(context).size.width;
    if (!_initialized) {
      return Container(
        height: screenW,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }

    return DoubleTapHeart(
      onDoubleTap: widget.onDoubleTap,
      child: GestureDetector(
        onTap: _togglePlay,
        child: SizedBox(
          height: screenW,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video
              Container(
                color: Colors.black,
                child: Center(
                  child: Video(controller: _controller),
                ),
              ),

              // Mute Icon Overlay
              Positioned(
                 bottom: 12,
                 right: 12,
                 child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                        isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 16,
                    ),
                 ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicPlayerWidget extends ConsumerStatefulWidget {
  final Map<String, dynamic> metadata;
  final bool isVisible;

  const _MusicPlayerWidget({required this.metadata, required this.isVisible});

  @override
  ConsumerState<_MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends ConsumerState<_MusicPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _previewUrl;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _previewUrl = widget.metadata['previewUrl'];
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      final isMuted = ref.watch(feedAudioProvider);

      // Audio Logic
      if (_previewUrl != null && _previewUrl!.isNotEmpty) {
          if (widget.isVisible && !isMuted) {
              if (!_isPlaying) {
                  _audioPlayer.play(UrlSource(_previewUrl!));
                  _isPlaying = true;
              }
              _audioPlayer.setVolume(1.0);
          } else {
              if (_isPlaying) {
                  _audioPlayer.pause();
                  _isPlaying = false;
              }
          }
      }

      return const SizedBox.shrink(); // Invisible Logic
  }
}
