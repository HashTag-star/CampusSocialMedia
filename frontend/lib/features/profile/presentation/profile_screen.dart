
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/profile/presentation/profile_provider.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:campus_social_media/core/constants/api_constants.dart';

class ProfileScreen extends ConsumerWidget {
  final String userId;
  final bool isMe;

  const ProfileScreen({super.key, required this.userId, this.isMe = false});

  String get _baseUrl => ApiConstants.baseUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Detect if the userId matches the current logged-in user
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = isMe || (currentUser != null && currentUser.id == userId);
    
    // Use 'me' endpoint for own profile to get accurate data
    final effectiveUserId = isOwnProfile ? 'me' : userId;
    final profileAsync = ref.watch(profileProvider(effectiveUserId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profile) => _buildProfile(context, ref, profile, theme, isDark, isOwnProfile),
      ),
    );
  }

  Widget _buildProfile(BuildContext context, WidgetRef ref, Map<String, dynamic> profile, ThemeData theme, bool isDark, bool isOwnProfile) {
    final posts = (profile['Posts'] as List?) ?? [];
    final followers = profile['followersCount'] ?? 0;
    final following = profile['followingCount'] ?? 0;
    final isFollowing = profile['isFollowing'] ?? false;
    final profileData = profile['profile_data'] as Map<String, dynamic>? ?? {};
    final avatarUrl = profileData['avatar_url'] as String?;
    final name = profileData['name'] ?? profile['email']?.split('@')[0] ?? 'User';
    final bio = profileData['bio'] as String?;
    final major = profileData['major'] as String?;
    final university = profile['University']?['name'] as String?;
    final uid = profile['id'] as String? ?? userId;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          // App Bar
          SliverAppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            pinned: true,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              if (isOwnProfile) ...[
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, size: 26),
                  onPressed: () => context.push('/feed/create-post'),
                ),
                IconButton(
                  icon: const Icon(Icons.menu, size: 26),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ],
          ),

          // Profile Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + Stats Row
                  Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Icon(Icons.person, size: 42, color: theme.colorScheme.onSurface)
                            : null,
                      ),
                      const SizedBox(width: 28),
                      // Stats
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatColumn(count: posts.length, label: 'Posts', onTap: () {}),
                            _StatColumn(
                              count: followers,
                              label: 'Followers',
                              onTap: () => context.push('/profile/$uid/followers', extra: {'showFollowers': true}),
                            ),
                            _StatColumn(
                              count: following,
                              label: 'Following',
                              onTap: () => context.push('/profile/$uid/followers', extra: {'showFollowers': false}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Name
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),

                  // Bio
                  if (bio != null && bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(bio, style: const TextStyle(fontSize: 14)),
                    ),

                  // Major & University
                  if (major != null || university != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [if (major != null) major, if (university != null) university].join(' • '),
                        style: TextStyle(fontSize: 13, color: theme.hintColor),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Action Buttons
                  if (isOwnProfile)
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Edit Profile',
                            onPressed: () => context.push('/profile/me/edit', extra: profile),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ActionButton(
                            label: 'Share Profile',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Share coming soon!')),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              onPressed: () => ref.read(followControllerProvider.notifier).toggleFollow(uid, isFollowing),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? (isDark ? Colors.white12 : Colors.grey[200])
                                    : const Color(0xFF3897F0),
                                foregroundColor: isFollowing
                                    ? theme.colorScheme.onSurface
                                    : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _ActionButton(
                            label: 'Message',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Messages coming soon!')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Tab Bar (Posts / Tagged)
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              child: Container(
                color: isDark ? Colors.black : Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.colorScheme.onSurface, width: 1),
                          ),
                        ),
                        child: Icon(Icons.grid_on, size: 24, color: theme.colorScheme.onSurface),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.transparent, width: 1),
                          ),
                        ),
                        child: Icon(Icons.person_pin_outlined, size: 24, color: theme.hintColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
      // Posts Grid
      body: posts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.onSurface, width: 2),
                    ),
                    child: Icon(Icons.camera_alt_outlined, size: 40, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isOwnProfile ? 'Share Photos' : 'No Posts Yet',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (isOwnProfile)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'When you share photos, they\'ll appear on your profile.',
                        style: TextStyle(color: theme.hintColor, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(1),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index] as Map<String, dynamic>;
                final mediaUrl = post['media_url'] as String?;
                final mediaType = post['media_type'] as String?;
                final mediaUrls = post['media_urls'] as List?;
                final postId = post['id'] as String? ?? '';

                Widget child;

                if (mediaUrl == null) {
                  // Text-only post
                  child = Container(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: Text(
                        post['caption'] ?? '',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                } else {
                  final imageUrl = mediaUrl.startsWith('http') ? mediaUrl : '$_baseUrl$mediaUrl';

                  child = Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                      // Carousel indicator
                      if (mediaType == 'carousel' && mediaUrls != null && mediaUrls.length > 1)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(Icons.collections, size: 16, color: Colors.white.withOpacity(0.9)),
                        ),
                      // Video indicator
                      if (mediaType == 'video')
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(Icons.play_arrow, size: 20, color: Colors.white.withOpacity(0.9)),
                        ),
                    ],
                  );
                }

                return GestureDetector(
                  onTap: () => context.push('/post/$postId', extra: {
                    'post': post,
                    'isOwner': isOwnProfile,
                  }),
                  child: child,
                );
              },
            ),
    );
  }
}

// ── Supporting Widgets ──

class _StatColumn extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback onTap;

  const _StatColumn({required this.count, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            _formatCount(count),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}K';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _TabHeaderDelegate({required this.child});

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) => false;
}
