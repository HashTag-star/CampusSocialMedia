import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/feed/data/feed_repository.dart';
import 'package:campus_social_media/features/feed/domain/post_entity.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';

// Type of feed to display
enum FeedType { campus, forYou }

final feedTypeProvider = StateProvider<FeedType>((ref) => FeedType.campus);

final feedNotifierProvider = StateNotifierProvider.autoDispose<FeedNotifier, AsyncValue<List<Post>>>((ref) {
  return FeedNotifier(ref.watch(feedRepositoryProvider), ref);
});

class FeedNotifier extends StateNotifier<AsyncValue<List<Post>>> {
  final FeedRepository _repository;
  final Ref _ref;

  FeedNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadFeed();
  }

  Future<void> loadFeed() async {
    if (!state.hasValue) state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      // Initial Load
      final type = _ref.read(feedTypeProvider);
      List<Post> posts;
      if (type == FeedType.campus) {
        posts = await _repository.getCampusFeed();
      } else {
        posts = await _repository.getForYouFeed();
      }
      
      // Update NewPostsNotifier with latest ID
      if (posts.isNotEmpty) {
        _ref.read(newPostsProvider.notifier).setLatestId(posts.first.id);
      }
      
      return posts;
    });
  }

  Future<void> refresh() async {
      final currentState = state.value;
      if (currentState == null || currentState.isEmpty) {
          return loadFeed();
      }

      // Fetch Newer Posts (Cursor = Top Post CreatedAt)
      final type = _ref.read(feedTypeProvider);
      if (type == FeedType.forYou) {
          try {
              final topPost = currentState.first;
              final newPosts = await _repository.getForYouFeed(
                  cursor: topPost.createdAt.toIso8601String(), 
                  direction: 'newer' // PREPEND
              );
              
              if (newPosts.isNotEmpty) {
                  state = AsyncValue.data([...newPosts, ...currentState]);
                  // Update NewPostsNotifier
                  _ref.read(newPostsProvider.notifier).setLatestId(newPosts.first.id);
              }
          } catch (e) {
              // Ignore refresh errors
          }
      } else {
          // Campus feed manual refresh
          await loadFeed();
      }
  }

  // ... loadMore, toggleLike, createPost, addComment, removePost ...
  Future<void> loadMore() async {
      final currentState = state.value;
      if (currentState == null || currentState.isEmpty) return;

      final type = _ref.read(feedTypeProvider);
      
      // Pagination only implemented for ForYou right now
      if (type == FeedType.forYou) {
           try {
              final lastPost = currentState.last;
              final morePosts = await _repository.getForYouFeed(
                  cursor: lastPost.createdAt.toIso8601String(), 
                  direction: 'older' // APPEND
              );
              
              if (morePosts.isNotEmpty) {
                  // Filter duplicates just in case
                  final existingIds = currentState.map((p) => p.id).toSet();
                  final uniqueNew = morePosts.where((p) => !existingIds.contains(p.id)).toList();
                  
                  if (uniqueNew.isNotEmpty) {
                      state = AsyncValue.data([...currentState, ...uniqueNew]);
                  }
              }
          } catch (e) {
              // Ignore load more errors
          }
      }
  }

  Future<void> toggleLike(String postId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return; // Not logged in?

    final currentList = state.value;
    if (currentList == null) return;

    // 1. Optimistic Update
    final index = currentList.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = currentList[index];
    final isLiked = post.isLikedByMe;
    
    final newIsLiked = !isLiked;
    final newCount = isLiked ? (post.likesCount - 1).coerceAtLeast(0) : (post.likesCount + 1);

    final updatedPost = post.copyWith(
      isLikedByMe: newIsLiked,
      likesCount: newCount,
    );

    final newList = List<Post>.from(currentList);
    newList[index] = updatedPost;
    
    state = AsyncValue.data(newList);

    // 2. Network Call
    try {
      await _repository.likePost(postId);
      // Success - do nothing, state is already correct
    } catch (e) {
      // Revert on error
      state = AsyncValue.data(currentList); 
      // Optionally show snackbar
    }
  }

  Future<void> createPost(String caption, List<String> mediaPaths, {String? location, List<String>? taggedUsers, Map<String, String>? musicMetadata}) async {
    await _repository.createPost(caption, mediaPaths, location: location, taggedUsers: taggedUsers, musicMetadata: musicMetadata);
    await loadFeed();
  }

  Future<void> addComment(String postId, String content) async {
    await _repository.addComment(postId, content);
    // Refresh to get updated comment count or optimistically increment
     final currentList = state.value;
    if (currentList != null) {
        final index = currentList.indexWhere((p) => p.id == postId);
        if (index != -1) {
            final post = currentList[index];
             final updatedPost = post.copyWith(commentsCount: post.commentsCount + 1);
             final newList = List<Post>.from(currentList);
             newList[index] = updatedPost;
             state = AsyncValue.data(newList);
        }
    }
  }
  Future<void> removePost(String postId) async {
      final currentList = state.value;
      if (currentList != null) {
          final newList = currentList.where((p) => p.id != postId).toList();
          state = AsyncValue.data(newList);
      }
  }
}

extension IntExtension on int {
  int coerceAtLeast(int min) => this < min ? min : this;
}

// Keep the same scroll controller provider
final feedScrollControllerProvider = Provider.autoDispose<ScrollController>((ref) {
  return ScrollController();
});

class NewPostsNotifier extends StateNotifier<List<String>> {
  final FeedRepository _repository;
  final Ref _ref;
  Timer? _timer;
  String? _currentTopId;

  NewPostsNotifier(this._repository, this._ref) : super([]) {
    _startPolling();
  }

  void setLatestId(String id) {
    _currentTopId = id;
    state = []; // Clear avatars when we have refreshed/loaded
  }

  void reset() {
    state = [];
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      // Don't poll if we don't know the current top
      if (_currentTopId == null) return;

      try {
        final type = _ref.read(feedTypeProvider);
        List<Post> latestPosts;
        
        if (type == FeedType.campus) {
           latestPosts = await _repository.getCampusFeed();
        } else {
           latestPosts = await _repository.getForYouFeed();
        }

        if (latestPosts.isEmpty) return;

        // Find how many new posts we have since _currentTopId
        // This is a simplified check. In real world, we'd paginate 'newer' than ID.
        // Here we just check the first N items of the feed.
        
        final newAvatars = <String>{};
        bool foundCurrent = false;

        for (final post in latestPosts) {
          if (post.id == _currentTopId) {
            foundCurrent = true;
            break;
          }
          if (post.user.avatarUrl != null) {
            newAvatars.add(post.user.avatarUrl!);
          }
        }

        if (foundCurrent && newAvatars.isNotEmpty) {
           // We found new posts on top!
           state = newAvatars.take(3).toList(); // Take top 3 unique avatars
        } else if (!foundCurrent && latestPosts.isNotEmpty) {
           // Current top is gone or invalid? Or more than 1 page of new posts?
           // Unlikely in 15s interval unless viral. Assume new posts.
           if (latestPosts.first.user.avatarUrl != null) {
              state = [latestPosts.first.user.avatarUrl!];
           } else {
              // No avatar, but new content
              state = ['default']; // Signal simple bubble
           }
        }
      } catch (e) {
        // Silent fail
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final newPostsProvider = StateNotifierProvider<NewPostsNotifier, List<String>>((ref) {
  return NewPostsNotifier(ref.watch(feedRepositoryProvider), ref);
});
