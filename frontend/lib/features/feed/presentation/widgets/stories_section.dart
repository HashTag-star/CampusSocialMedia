import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/feed/data/feed_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:campus_social_media/features/stories/presentation/story_viewer_screen.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:campus_social_media/features/stories/presentation/create_story_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/story_skeleton.dart';

final storiesProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.getStories();
});

// Seen stories tracker — stores "userId -> latestSeenStoryId"
final _seenStoriesProvider = StateProvider<Map<String, String>>((ref) => {});

class StoriesSection extends ConsumerStatefulWidget {
  const StoriesSection({super.key});

  @override
  ConsumerState<StoriesSection> createState() => _StoriesSectionState();
}

class _StoriesSectionState extends ConsumerState<StoriesSection> {
  @override
  void initState() {
    super.initState();
    _loadSeenStories();
  }

  Future<void> _loadSeenStories() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('seen_story_'));
    final map = <String, String>{};
    for (final key in keys) {
      final userId = key.replaceFirst('seen_story_', '');
      map[userId] = prefs.getString(key) ?? '';
    }
    if (mounted) {
      ref.read(_seenStoriesProvider.notifier).state = map;
    }
  }

  Future<void> _markAsSeen(String userId, String latestStoryId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seen_story_$userId', latestStoryId);
    if (mounted) {
      ref.read(_seenStoriesProvider.notifier).state = {
        ...ref.read(_seenStoriesProvider),
        userId: latestStoryId,
      };
    }
  }

  bool _isSeen(String userId, List<dynamic> stories) {
    final seenMap = ref.read(_seenStoriesProvider);
    final lastSeenId = seenMap[userId];
    if (lastSeenId == null) return false;
    // Check if the latest story is the one we've seen
    final latestId = stories.last['id']?.toString() ?? '';
    return lastSeenId == latestId;
  }

  void _createStory() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
    ).then((_) {
      // Refresh stories after returning
      ref.invalidate(storiesProvider);
    });
  }

  void _openStoryViewer(Map<String, dynamic> group) {
    final userId = (group['user'] as Map<String, dynamic>?)?['id']?.toString() ?? '';
    final stories = group['stories'] as List<dynamic>;
    final latestId = stories.last['id']?.toString() ?? '';

    // Mark as seen
    _markAsSeen(userId, latestId);

    context.push('/story', extra: group);
  }

  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(storiesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final seenMap = ref.watch(_seenStoriesProvider);

    return SliverToBoxAdapter(
      child: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
        ),
        child: storiesAsync.when(
          data: (storyGroups) {
            // Find current user's story group (if any)
            Map<String, dynamic>? myGroup;
            final otherGroups = <Map<String, dynamic>>[];

            for (final g in storyGroups) {
              final group = g as Map<String, dynamic>;
              final user = group['user'] as Map<String, dynamic>?;
              if (user != null && user['id'] == currentUser?.id) {
                myGroup = group;
              } else {
                otherGroups.add(group);
              }
            }

            // Sort: unseen first
            otherGroups.sort((a, b) {
              final aUserId = (a['user'] as Map<String, dynamic>?)?['id']?.toString() ?? '';
              final bUserId = (b['user'] as Map<String, dynamic>?)?['id']?.toString() ?? '';
              final aSeen = _isSeen(aUserId, a['stories'] as List<dynamic>);
              final bSeen = _isSeen(bUserId, b['stories'] as List<dynamic>);
              if (aSeen && !bSeen) return 1;
              if (!aSeen && bSeen) return -1;
              return 0;
            });

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: otherGroups.length + 1, // +1 for "Your Story"
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "Your Story"
                  return _buildMyStory(myGroup, currentUser);
                }

                final group = otherGroups[index - 1];
                final user = group['user'] as Map<String, dynamic>?;
                final stories = group['stories'] as List<dynamic>;
                final userId = user?['id']?.toString() ?? '';
                final name = user?['profile_data']?['name']?.toString().split(' ')[0]
                    ?? user?['email']?.toString().split('@')[0]
                    ?? 'User';

                // Use first story's media as thumbnail
                final thumbnailUrl = stories.isNotEmpty
                    ? stories.first['media_url']?.toString() ?? ''
                    : '';

                final seen = _isSeen(userId, stories);

                return GestureDetector(
                  onTap: () => _openStoryViewer(group),
                  child: _StoryItem(
                    name: name,
                    imgUrl: thumbnailUrl,
                    isSeen: seen,
                  ),
                );
              },
            );
          },
          loading: () => const StorySkeleton(),
          error: (err, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildMyStory(Map<String, dynamic>? myGroup, dynamic currentUser) {
    final avatarUrl = currentUser?.avatarUrl as String?;
    final hasStory = myGroup != null;

    if (hasStory) {
      // User has an active story — show first story thumbnail with gradient ring
      final stories = myGroup!['stories'] as List<dynamic>;
      final thumbnailUrl = stories.isNotEmpty ? stories.first['media_url']?.toString() ?? '' : '';

      return GestureDetector(
        onTap: () => _openStoryViewer(myGroup),
        onLongPress: _createStory, // long-press to add more
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Gradient ring
                Container(
                  width: 68, height: 68,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFBAA47), Color(0xFFD91A46), Color(0xFFA60F93)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                  ),
                ),
                // Thumbnail
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: thumbnailUrl.isNotEmpty
                        ? DecorationImage(image: CachedNetworkImageProvider(thumbnailUrl), fit: BoxFit.cover)
                        : null,
                    color: thumbnailUrl.isEmpty ? Colors.grey[300] : null,
                  ),
                  child: thumbnailUrl.isEmpty ? const Icon(Icons.person, size: 30, color: Colors.grey) : null,
                ),
                // Small "+" to add more
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3897F0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your Story',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    // No active story — show profile pic with "+" badge
    return GestureDetector(
      onTap: _createStory,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Profile pic
              Container(
                width: 68, height: 68,
                padding: const EdgeInsets.all(4),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                  backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Icon(Icons.person, size: 30, color: Theme.of(context).hintColor)
                      : null,
                ),
              ),
              // "+" badge
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3897F0),
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                  child: const Icon(Icons.add, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your Story',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final String name;
  final String imgUrl;
  final bool isSeen;

  const _StoryItem({required this.name, required this.imgUrl, this.isSeen = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Ring — gradient for unseen, grey for seen
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSeen
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFBAA47), Color(0xFFD91A46), Color(0xFFA60F93)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                color: isSeen ? Colors.grey.shade400 : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
            // Story thumbnail
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: imgUrl.isNotEmpty
                    ? DecorationImage(image: CachedNetworkImageProvider(imgUrl), fit: BoxFit.cover)
                    : null,
                color: imgUrl.isEmpty ? Colors.grey[300] : null,
              ),
              child: imgUrl.isEmpty ? const Icon(Icons.person, size: 28, color: Colors.grey) : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
