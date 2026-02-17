import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/profile/presentation/profile_provider.dart';

class FollowersFollowingScreen extends ConsumerWidget {
  final String userId;
  final bool showFollowers; // true = followers tab, false = following tab

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    this.showFollowers = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      initialIndex: showFollowers ? 0 : 1,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Connections',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.onSurface,
            unselectedLabelColor: theme.hintColor,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UserListTab(
              dataProvider: followersProvider(userId),
              emptyMessage: 'No followers yet',
              emptyIcon: Icons.people_outline,
            ),
            _UserListTab(
              dataProvider: followingProvider(userId),
              emptyMessage: 'Not following anyone',
              emptyIcon: Icons.person_add_alt_1_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserListTab extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<dynamic>>> dataProvider;
  final String emptyMessage;
  final IconData emptyIcon;

  const _UserListTab({
    required this.dataProvider,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncUsers = ref.watch(dataProvider);

    return asyncUsers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, size: 64, color: theme.hintColor.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(emptyMessage, style: TextStyle(color: theme.hintColor, fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index] as Map<String, dynamic>;
            // Handle both flat and nested structures
            final profileData = user['profile_data'] as Map<String, dynamic>? ?? {};
            final name = profileData['name'] ?? user['email']?.split('@')[0] ?? 'User';
            final avatarUrl = profileData['avatar_url'];
            final bio = profileData['bio'] as String?;
            final uid = user['id'] as String;

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl == null
                    ? Icon(Icons.person, size: 20, color: theme.colorScheme.onSurface)
                    : null,
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: bio != null
                  ? Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.hintColor))
                  : null,
              trailing: _FollowButton(userId: uid),
              onTap: () => context.push('/profile/$uid'),
            );
          },
        );
      },
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String userId;
  const _FollowButton({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // We don't have per-user follow state here, so show a generic view button
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: () => context.push('/profile/$userId'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: const Text('View', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}
