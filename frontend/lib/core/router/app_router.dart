import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/auth/presentation/login_screen.dart';
import 'package:campus_social_media/features/auth/presentation/register_screen.dart';
import 'package:campus_social_media/features/auth/presentation/onboarding_screen.dart';
import 'package:campus_social_media/features/splash/presentation/splash_screen.dart';
import 'package:campus_social_media/features/feed/presentation/feed_screen.dart';
import 'package:campus_social_media/features/post/presentation/create_post_screen.dart';
import 'package:campus_social_media/features/spaces/presentation/spaces_screen.dart';
import 'package:campus_social_media/features/spaces/presentation/active_space_screen.dart';
import 'package:campus_social_media/features/spaces/domain/space_entity.dart';
import 'package:campus_social_media/features/profile/presentation/profile_screen.dart';
import 'package:campus_social_media/features/feed/presentation/widgets/glass_nav_bar.dart';
import 'package:campus_social_media/features/search/presentation/explore_screen.dart';
import 'package:campus_social_media/features/shorts/presentation/shorts_screen.dart';
import 'package:campus_social_media/features/profile/presentation/settings_screen.dart';
import 'package:campus_social_media/features/profile/presentation/edit_profile_screen.dart';
import 'package:campus_social_media/features/profile/presentation/followers_following_screen.dart';
import 'package:campus_social_media/features/post/presentation/post_detail_screen.dart';
import 'package:campus_social_media/features/notifications/presentation/notifications_screen.dart';
import 'package:campus_social_media/features/messaging/presentation/conversations_screen.dart';
import 'package:campus_social_media/features/messaging/presentation/chat_screen.dart';
import 'package:campus_social_media/features/messaging/presentation/new_message_screen.dart';
import 'package:campus_social_media/features/shorts/presentation/reel_viewer_screen.dart';
import 'package:campus_social_media/features/feed/domain/post_entity.dart';
import 'package:campus_social_media/features/shorts/presentation/create_reel_screen.dart';
import 'package:campus_social_media/features/stories/presentation/story_viewer_screen.dart';

// Private Nav Key
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Persistent Bottom Nav Shell
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return ScaffoldWithNavBar(child: child);
        },
        routes: [
          // 0. Home / Feed
          GoRoute(
            path: '/feed',
            pageBuilder: (context, state) => const NoTransitionPage(child: FeedScreen()),
            routes: [
              GoRoute(
                parentNavigatorKey: _rootNavigatorKey, // Full screen, covers nav bar
                path: 'create-post',
                builder: (context, state) => const CreatePostScreen(),
              ),
              GoRoute(
                parentNavigatorKey: _rootNavigatorKey,
                path: 'notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
            ]
          ),
          
          // 1. Explore
          GoRoute(
            path: '/explore',
            pageBuilder: (context, state) => const NoTransitionPage(child: ExploreScreen()),
          ),
          

          
          // 3. Spaces
          GoRoute(
            path: '/spaces',
            pageBuilder: (context, state) => const NoTransitionPage(child: SpacesScreen()),
            routes: [
               GoRoute(
                parentNavigatorKey: _rootNavigatorKey,
                path: 'active',
                builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>;
                    return ActiveSpaceScreen(
                        space: extra['space'] as Space,
                        token: extra['token'] as String,
                    );
                },
              ),
            ]
          ),
          
          // 4. Profile
          GoRoute(
            path: '/profile/me',
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen(userId: 'me', isMe: true)),
            routes: [
              GoRoute(
                parentNavigatorKey: _rootNavigatorKey,
                path: 'edit',
                builder: (context, state) {
                  final profile = state.extra as Map<String, dynamic>;
                  return EditProfileScreen(profile: profile);
                },
              ),
            ],
          ),
        ],
      ),

      // Other Routes (external to shell)
      GoRoute(
        path: '/profile/:userId',
        parentNavigatorKey: _rootNavigatorKey, 
        builder: (context, state) {
           final userId = state.pathParameters['userId']!;
           return ProfileScreen(userId: userId, isMe: false);
        },
        routes: [
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: 'followers',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              final extra = state.extra as Map<String, dynamic>? ?? {};
              final showFollowers = extra['showFollowers'] as bool? ?? true;
              return FollowersFollowingScreen(userId: userId, showFollowers: showFollowers);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/messages',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ConversationsScreen(),
        routes: [
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: 'chat/:conversationId',
            builder: (context, state) {
              final conversationId = state.pathParameters['conversationId']!;
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return ChatScreen(
                conversationId: conversationId,
                otherUserName: extra['otherUserName'] ?? 'User',
                otherUserId: extra['otherUserId'] ?? '',
              );
            },
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: 'new',
            builder: (context, state) => const NewMessageScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/post/:postId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final post = extra['post'] as Map<String, dynamic>;
          final isOwner = extra['isOwner'] as bool? ?? false;
          return PostDetailScreen(post: post, isOwner: isOwner);
        },
      ),
      GoRoute(
        path: '/reel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final posts = extra['posts'] as List<Post>;
          final initialIndex = extra['initialIndex'] as int? ?? 0;
          return ReelViewerScreen(posts: posts, initialIndex: initialIndex);
        },
      ),
      GoRoute(
        path: '/create-reel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateReelScreen(),
      ),
      GoRoute(
        path: '/shorts',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => const NoTransitionPage(child: ShortsScreen()),
      ),
      GoRoute(
        path: '/story',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final group = state.extra as Map<String, dynamic>;
          return CustomTransitionPage(
            child: StoryViewerScreen(userStoryGroup: group),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          );
        },
      ),
    ],
  );
});

class ScaffoldWithNavBar extends StatefulWidget {
  final Widget child;
  const ScaffoldWithNavBar({super.key, required this.child});

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/feed')) return 0;
    if (location.startsWith('/explore')) return 1;
    if (location.startsWith('/shorts')) return 2;
    if (location.startsWith('/spaces')) return 3;
    if (location.startsWith('/profile/me')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/feed');
        break;
      case 1:
        context.go('/explore');
        break;
      case 2:
        context.push('/shorts');
        break;
      case 3:
        context.go('/spaces');
        break;
      case 4:
        context.go('/profile/me');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: GlassNavBar(
        selectedIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
      ),
    );
  }
}
