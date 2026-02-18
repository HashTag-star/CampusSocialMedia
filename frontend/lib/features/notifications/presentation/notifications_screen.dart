import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/notifications/data/notification_repository.dart';
import 'package:campus_social_media/features/profile/data/profile_repository.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:campus_social_media/core/widgets/error_retry_widget.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when opening screen (optional, or do it on item tap)
    Future.microtask(() => 
      ref.read(notificationRepositoryProvider).markAllAsRead()
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text('No notifications yet', style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationItem(notification: notification);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => ErrorRetryWidget(
          message: err.toString(),
          onRetry: () => ref.refresh(notificationsProvider),
        ),
      ),
    );
  }
}

class _NotificationItem extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final actor = notification.actor;

    IconData icon;
    Color iconColor;
    String text;

    switch (notification.type) {
      case 'follow':
        icon = Icons.person_add; // This might be wrong icon for now
        iconColor = Colors.blue;
        text = 'started following you.';
        break;
      case 'suggestion':
        icon = Icons.auto_awesome;
        iconColor = Colors.purple;
        text = 'is someone you might know.';
        break;
      case 'like':
        icon = Icons.favorite;
        iconColor = Colors.red;
        text = 'liked your post.';
        break;
      case 'comment':
        icon = Icons.chat_bubble;
        iconColor = Colors.green;
        text = 'commented: "${notification.message ?? ''}"';
        break;
      default:
        icon = Icons.notifications;
        iconColor = theme.colorScheme.primary;
        text = notification.message ?? 'New notification';
    }

    return InkWell(
      onTap: () {
        if (actor != null) {
          context.push('/profile/${actor.id}');
        }
      },
      child: Container(
        color: notification.isRead ? Colors.transparent : theme.colorScheme.primary.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Actor Avatar
            if (actor != null)
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(actor.profileData?['avatar_url'] ?? 'https://i.pravatar.cc/150?u=${actor.id}'),
              )
            else
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.surfaceVariant,
                child: Icon(icon, color: iconColor, size: 20),
              ),
            
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        if (actor != null)
                          TextSpan(
                            text: '${actor.profileData?['name'] ?? actor.email.split('@')[0]} ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        TextSpan(text: text),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(notification.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),

            // Action Button (Follow back)
            if (notification.type == 'suggestion' && actor != null)
               _FollowButton(userId: actor.id),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  final String userId;
  const _FollowButton({required this.userId});
  
  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool isFollowing = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        setState(() => isFollowing = !isFollowing);
        if (isFollowing) {
           await ref.read(profileRepositoryProvider).followUser(widget.userId);
        } else {
           await ref.read(profileRepositoryProvider).unfollowUser(widget.userId);
        }
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minimumSize: const Size(60, 32),
        backgroundColor: isFollowing ? Colors.grey[200] : Theme.of(context).colorScheme.primary,
        foregroundColor: isFollowing ? Colors.black : Colors.white,
      ),
      child: Text(isFollowing ? 'Sent' : 'Follow', style: const TextStyle(fontSize: 12)),
    );
  }
}
