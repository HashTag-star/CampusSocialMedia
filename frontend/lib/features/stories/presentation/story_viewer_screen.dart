import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:campus_social_media/features/stories/data/story_repository.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoryViewerScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> userStoryGroup;

  const StoryViewerScreen({super.key, required this.userStoryGroup});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;
  bool _hasPopped = false;
  bool _isPaused = false;
  final TextEditingController _replyController = TextEditingController();
  bool _isLiked = false;

  List<dynamic> get stories => widget.userStoryGroup['stories'] as List<dynamic>;
  Map<String, dynamic>? get user => widget.userStoryGroup['user'] as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    
    // Initial setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onStoryChanged();
      _progressController.forward();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _onStoryChanged() {
    final story = stories[_currentIndex];
    final storyId = story['id'].toString();
    
    // Reset like state (locally for now, ideally fetched from backend)
    setState(() => _isLiked = false);

    // Record view
    ref.read(storyRepositoryProvider).viewStory(storyId);
  }

  void _close() {
    if (!mounted || _hasPopped) return;
    _hasPopped = true;
    _progressController.stop();
    Navigator.of(context).pop();
  }

  void _nextStory() {
    if (!mounted) return;
    if (_currentIndex < stories.length - 1) {
      setState(() => _currentIndex++);
      _progressController.reset();
      _onStoryChanged();
      _progressController.forward();
    } else {
      _close();
    }
  }

  void _prevStory() {
    if (!mounted) return;
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressController.reset();
      _onStoryChanged();
      _progressController.forward();
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _pause() {
    if (!_isPaused) {
      setState(() => _isPaused = true);
      _progressController.stop();
    }
  }

  void _resume() {
    if (_isPaused) {
      setState(() => _isPaused = false);
      _progressController.forward();
    }
  }

  Future<void> _sendReply(String storyId) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    
    _pause();
    
    // Send to backend
    await ref.read(storyRepositoryProvider).interactStory(
      storyId: storyId,
      reply: text,
    );
    
    _replyController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent!')),
      );
      _resume();
    }
  }

  Future<void> _toggleLike(String storyId) async {
    setState(() => _isLiked = !_isLiked);
    await ref.read(storyRepositoryProvider).interactStory(
      storyId: storyId,
      liked: _isLiked,
    );
  }

  void _showViewers(String storyId) {
    _pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _ViewersListSheet(storyId: storyId),
    ).then((_) => _resume());
  }

  @override
  Widget build(BuildContext context) {
    final story = stories[_currentIndex];
    final storyId = story['id'].toString();
    final username = user?['profile_data']?['name'] ??
        user?['email']?.split('@')[0] ??
        'User';
    final avatarUrl = user?['profile_data']?['avatar_url'] as String?;
    final createdAtRaw = story['created_at'] ?? story['createdAt'];
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now()
        : DateTime.now();
    final mediaUrl = story['media_url']?.toString() ?? '';
    
    final currentUser = ref.watch(currentUserProvider);
    final isMyStory = currentUser?.id == user?['id'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onTapUp: (details) {
          if (_isPaused) return; // Ignore taps while paused (e.g. typing)
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < screenWidth / 3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            _close();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: CachedNetworkImage(
                key: ValueKey(mediaUrl),
                imageUrl: mediaUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),

            // Gradients
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),

            // Progress Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8, right: 8,
              child: Row(
                children: List.generate(stories.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1.5),
                        child: SizedBox(
                          height: 2.5,
                          child: index < _currentIndex
                              ? const LinearProgressIndicator(value: 1.0, color: Colors.white)
                              : index == _currentIndex
                                  ? AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (_, __) => LinearProgressIndicator(
                                        value: _progressController.value,
                                        color: Colors.white,
                                        backgroundColor: Colors.white30,
                                      ),
                                    )
                                  : const LinearProgressIndicator(value: 0.0, backgroundColor: Colors.white30),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // User Info
            Positioned(
              top: MediaQuery.of(context).padding.top + 18,
              left: 12, right: 12,
              child: Row(
                children: [
                   CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF262626),
                    backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    username,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeago.format(createdAt, locale: 'en_short'),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _close,
                  ),
                ],
              ),
            ),

            // Caption
            if (story['caption'] != null && story['caption'].toString().isNotEmpty)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 80,
                left: 16, right: 16,
                child: Text(
                  story['caption'],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),

            // Bottom Controls (My Story vs Other's Story)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 12,
              left: 16, right: 16,
              child: isMyStory
                  ? GestureDetector(
                      onTap: () => _showViewers(storyId),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye, color: Colors.white, size: 20),
                          const SizedBox(width: 6),
                          const Text(
                            'Activity', 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: TextField(
                              controller: _replyController,
                              style: const TextStyle(color: Colors.white),
                              cursorColor: Colors.white,
                              onTap: _pause, // Pause when typing
                              onSubmitted: (_) => _sendReply(storyId),
                              decoration: InputDecoration(
                                hintText: 'Send message...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                                  onPressed: () => _sendReply(storyId),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _toggleLike(storyId),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isLiked ? Colors.red.withOpacity(0.2) : Colors.transparent,
                            ),
                            child: Icon(
                              _isLiked ? Icons.favorite : Icons.favorite_border,
                              color: _isLiked ? Colors.red : Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewersListSheet extends ConsumerStatefulWidget {
  final String storyId;
  const _ViewersListSheet({required this.storyId});

  @override
  ConsumerState<_ViewersListSheet> createState() => _ViewersListSheetState();
}

class _ViewersListSheetState extends ConsumerState<_ViewersListSheet> {
  late Future<List<dynamic>> _viewersFuture;

  @override
  void initState() {
    super.initState();
    _viewersFuture = ref.read(storyRepositoryProvider).getStoryViewers(widget.storyId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Viewers',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _viewersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white54)));
                }
                final viewers = snapshot.data ?? [];
                if (viewers.isEmpty) {
                  return const Center(child: Text('No views yet', style: TextStyle(color: Colors.white54)));
                }

                return ListView.separated(
                  itemCount: viewers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final view = viewers[index];
                    final user = view['viewer'];
                    final name = user['profile_data']?['name'] ?? user['email'] ?? 'User';
                    final avatarUrl = user['profile_data']?['avatar_url'];
                    final liked = view['liked'] == true;
                    final reply = view['reply'] as String?;

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                          child: avatarUrl == null ? const Icon(Icons.person) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              if (reply != null)
                                Text('Replied: $reply', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (liked)
                          const Icon(Icons.favorite, color: Colors.red, size: 16),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
