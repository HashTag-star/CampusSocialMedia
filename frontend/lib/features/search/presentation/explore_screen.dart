import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:campus_social_media/features/feed/data/feed_repository.dart';
import 'package:campus_social_media/features/feed/domain/post_entity.dart';
import 'package:campus_social_media/features/profile/data/profile_repository.dart';
import 'package:campus_social_media/core/constants/api_constants.dart';

// ── Providers ──────────────────────────────────────────────

final _searchQueryProvider = StateProvider<String>((ref) => '');

final _postSearchProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.watch(feedRepositoryProvider).searchPosts(query);
});

final _userSearchProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.watch(profileRepositoryProvider).searchUsers(query);
});

final _exploreFeedProvider = FutureProvider<List<Post>>((ref) async {
  return ref.watch(feedRepositoryProvider).getCampusFeed();
});

// ── Explore Screen ─────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    _focusNode.requestFocus();
  }

  void _cancelSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    _focusNode.unfocus();
    ref.read(_searchQueryProvider.notifier).state = '';
  }

  void _onSearch(String query) {
    ref.read(_searchQueryProvider.notifier).state = query.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _isSearching ? null : _startSearch,
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _isSearching
                            ? TextField(
                                controller: _searchController,
                                focusNode: _focusNode,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(color: theme.hintColor, fontSize: 15),
                                  prefixIcon: Icon(Icons.search, color: theme.hintColor, size: 20),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  isDense: true,
                                ),
                                onChanged: _onSearch,
                                textInputAction: TextInputAction.search,
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search, color: theme.hintColor, size: 18),
                                  const SizedBox(width: 6),
                                  Text('Search', style: TextStyle(color: theme.hintColor, fontSize: 15)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (_isSearching) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _cancelSearch,
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildExploreGrid(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search Results ──

  Widget _buildSearchResults() {
    final query = ref.watch(_searchQueryProvider);
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Theme.of(context).hintColor.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'Search for people and posts',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final usersAsync = ref.watch(_userSearchProvider);
    final postsAsync = ref.watch(_postSearchProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      children: [
        // Users Section
        usersAsync.when(
          data: (users) {
            if (users.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('People', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                ...users.map((user) {
                  final profileData = user['profile_data'] as Map<String, dynamic>? ?? {};
                  final name = profileData['name'] ?? user['email']?.split('@')[0] ?? 'User';
                  final avatarUrl = profileData['avatar_url'] as String?;
                  final bio = profileData['bio'] as String? ?? '';
                  final userId = user['id'] as String;

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Icon(Icons.person, size: 20, color: theme.hintColor)
                          : null,
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: bio.isNotEmpty
                        ? Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: theme.hintColor))
                        : Text(user['email'] ?? '', style: TextStyle(fontSize: 13, color: theme.hintColor)),
                    onTap: () => context.push('/profile/$userId'),
                  );
                }),
                const Divider(height: 1),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Posts Section
        postsAsync.when(
          data: (posts) {
            if (posts.isEmpty && usersAsync.valueOrNull?.isEmpty == true) {
              return Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: theme.hintColor.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No results found', style: TextStyle(color: theme.hintColor)),
                    ],
                  ),
                ),
              );
            }
            if (posts.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('Posts', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(1),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => _ExploreTile(post: posts[index]),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Explore Grid (IG-style masonry) ──

  Widget _buildExploreGrid() {
    final exploreFeed = ref.watch(_exploreFeedProvider);

    return exploreFeed.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_outlined, size: 64, color: Theme.of(context).hintColor.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text('Nothing to explore yet', style: TextStyle(color: Theme.of(context).hintColor)),
              ],
            ),
          );
        }

        // Filter to media posts for the grid
        final mediaPosts = posts.where((p) => p.mediaUrl != null).toList();
        if (mediaPosts.isEmpty) {
          return Center(
            child: Text('No media posts to explore', style: TextStyle(color: Theme.of(context).hintColor)),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(_exploreFeedProvider.future),
          child: _IGMasonryGrid(posts: mediaPosts, screenWidth: MediaQuery.of(context).size.width),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── IG-style Masonry Grid ──────────────────────────────────
// Instagram's Explore uses a repeating 3-column pattern:
// Row type A: 3 equal squares
// Row type B: 1 large (2x2) + 2 stacked squares (alternating left/right)
// Pattern repeats: A, B-left, A, B-right, A, etc.

class _IGMasonryGrid extends StatelessWidget {
  final List<Post> posts;
  final double screenWidth;
  const _IGMasonryGrid({required this.posts, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];
    int i = 0;
    int bVariant = 0; // 0 = large left, 1 = large right

    while (i < posts.length) {
      // Row A: 3 equal tiles
      if (i + 3 <= posts.length) {
        rows.add(_buildRowA(posts.sublist(i, i + 3)));
        i += 3;
      } else {
        // Remaining posts as row A (partial)
        rows.add(_buildRowA(posts.sublist(i)));
        i = posts.length;
        break;
      }

      // Row B: 1 large + 2 small
      if (i + 3 <= posts.length) {
        rows.add(_buildRowB(posts.sublist(i, i + 3), bVariant % 2 == 0));
        bVariant++;
        i += 3;
      } else if (i < posts.length) {
        rows.add(_buildRowA(posts.sublist(i)));
        i = posts.length;
      }
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: rows,
    );
  }

  // 3 equal squares in a row
  Widget _buildRowA(List<Post> rowPosts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          for (int i = 0; i < rowPosts.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(child: AspectRatio(aspectRatio: 1, child: _ExploreTile(post: rowPosts[i]))),
          ],
          // fill empty spots
          for (int i = rowPosts.length; i < 3; i++) ...[
            const SizedBox(width: 2),
            const Expanded(child: AspectRatio(aspectRatio: 1, child: SizedBox())),
          ],
        ],
      ),
    );
  }

  // 1 large (2x2) + 2 stacked small
  Widget _buildRowB(List<Post> rowPosts, bool largeOnLeft) {
    final largeTile = _ExploreTile(post: rowPosts[0]);
    final smallColumn = Column(
      children: [
        Expanded(child: SizedBox(width: double.infinity, child: _ExploreTile(post: rowPosts[1]))),
        const SizedBox(height: 2),
        Expanded(child: SizedBox(width: double.infinity, child: _ExploreTile(post: rowPosts[2]))),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        height: (screenWidth / 3) * 2 + 2,
        child: Row(
          children: largeOnLeft
              ? [
                  Expanded(flex: 2, child: largeTile),
                  const SizedBox(width: 2),
                  Expanded(flex: 1, child: smallColumn),
                ]
              : [
                  Expanded(flex: 1, child: smallColumn),
                  const SizedBox(width: 2),
                  Expanded(flex: 2, child: largeTile),
                ],
        ),
      ),
    );
  }
}

// ── Single Explore Tile ────────────────────────────────────

class _ExploreTile extends StatelessWidget {
  final Post post;
  const _ExploreTile({required this.post});

  @override
  Widget build(BuildContext context) {
    if (post.mediaUrl == null) {
      return Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : Colors.grey[100],
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Text(
            post.caption ?? '',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      );
    }

    final imageUrl = post.mediaUrl!.startsWith('http')
        ? post.mediaUrl!
        : '${ApiConstants.baseUrl}${post.mediaUrl}';

    return GestureDetector(
      onTap: () {
        context.push('/post/${post.id}', extra: {
          'post': {
            'id': post.id,
            'caption': post.caption,
            'media_url': post.mediaUrl,
            'media_type': post.mediaType,
            'media_urls': post.mediaUrls,
            'createdAt': post.createdAt.toIso8601String(),
            'User': {
              'id': post.user.id,
              'email': post.user.email,
              'profile_data': {
                'name': post.user.name,
                'avatar_url': post.user.avatarUrl,
              },
            },
          },
          'isOwner': false,
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : Colors.grey[200],
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.broken_image, size: 24)),
            ),
          ),
          // Carousel indicator
          if (post.mediaType == 'carousel' && post.mediaUrls.length > 1)
            Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.collections, size: 14, color: Colors.white.withOpacity(0.9)),
            ),
          // Video indicator
          if (post.mediaType == 'video')
            Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.play_arrow, size: 18, color: Colors.white.withOpacity(0.9)),
            ),
        ],
      ),
    );
  }
}
