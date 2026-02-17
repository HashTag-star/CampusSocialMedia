import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/feed/presentation/feed_provider.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/post_card.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/ambient_background.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/stories_section.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/glass_nav_bar.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/post_skeleton.dart';
import 'package:campus_social_media/features/notifications/data/notification_repository.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController =  ScrollController(); // We can manage it locally or use the provider. 
    // The provider was autoDispose, might be better to own it here.
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedNotifierProvider);
    final feedType = ref.watch(feedTypeProvider);
    final hasNewPosts = ref.watch(newPostsProvider);
    // final scrollController = ref.watch(feedScrollControllerProvider); // Use local instead

    ref.listen(feedNotifierProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Could not load feed. Please try again.', style: TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    });

    return Scaffold(
      // ... existing Scaffold properties ...
      extendBody: true, // Allow body to stretch behind nav bar
      body: Stack(
        children: [
          // 1. Ambient Background layer
          const AmbientBackground(),

          // 2. Main Scrollable Content
          RefreshIndicator(
            onRefresh: () async {
              // Manual Pull-to-Refresh
              ref.read(newPostsProvider.notifier).reset(); // Clear bubble if visible
              return ref.read(feedNotifierProvider.notifier).refresh();
            },
            color: Theme.of(context).colorScheme.primary,
            edgeOffset: 110, // Push it down below the glass header
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(), // Ensure it can always scroll/refresh
              slivers: [
                // Glass AppBar
                SliverAppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leadingWidth: 48,
                  leading: IconButton(
                    icon: const Icon(Icons.add_box_outlined, size: 28),
                    onPressed: () => context.push('/feed/create-post'),
                    padding: EdgeInsets.zero,
                  ),
                  centerTitle: true,
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Uni',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Gram',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, size: 28),
                          onPressed: () => context.push('/feed/notifications'),
                        ),
                        // We can use a provider to check if there are unread notifications
                        // For now we will just check if there are ANY notifications
                        Consumer(
                          builder: (context, ref, child) {
                            final notificationsAsync = ref.watch(notificationsProvider);
                             return notificationsAsync.maybeWhen(
                                data: (notifications) {
                                   final hasUnread = notifications.any((n) => !n.isRead);
                                   if (hasUnread) {
                                     return Positioned(
                                       right: 12,
                                       top: 12,
                                       child: Container(
                                         width: 8,
                                         height: 8,
                                         decoration: const BoxDecoration(
                                           color: Colors.red,
                                           shape: BoxShape.circle,
                                         ),
                                       ),
                                     );
                                   }
                                   return const SizedBox.shrink();
                                },
                                orElse: () => const SizedBox.shrink(),
                             );
                          }
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 26),
                      onPressed: () => context.push('/messages'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // Stories
                const StoriesSection(),

                // Posts List
                feedState.when(
                  data: (posts) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // Add padding at bottom for nav bar
                        if (index == posts.length - 1) {
                           return Padding(
                             padding: const EdgeInsets.only(bottom: 80), // Standard nav height + buffer
                             child: PostCard(post: posts[index]),
                           );
                        }
                        return PostCard(post: posts[index]);
                      },
                      childCount: posts.length,
                    ),
                  ),
                  loading: () => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const PostSkeleton(),
                    childCount: 5, // Show 5 skeleton items
                  ),
                ),
                  error: (err, stack) => SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off, size: 60, color: Theme.of(context).disabledColor),
                          const SizedBox(height: 16),
                          Text(
                            "Something went wrong",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref.read(feedNotifierProvider.notifier).refresh(),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Floating Add Button Removed (Moved to NavBar)

          // 5. New Posts Bubble
           if (hasNewPosts)
             Positioned(
              top: 140, // Below AppBar + Tabs
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // Prepend new posts
                    ref.read(feedNotifierProvider.notifier).refresh();
                    _scrollController.animateTo(
                      0, 
                      duration: const Duration(milliseconds: 500), 
                      curve: Curves.easeOut
                    );
                    ref.read(newPostsProvider.notifier).reset();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'New posts',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: isSelected ? null : Border.all(color: theme.dividerColor),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isSelected ? Colors.white : theme.hintColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
