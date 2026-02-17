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
                  // "X-Style": Old posts eventually leave? 
                  // For now, we just prepend. User can scroll down to see old.
              }
          } catch (e) {
              // Ignore refresh errors
          }
      } else {
          return loadFeed(); // Campus feed doesn't verify pagination yet
      }
  }

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

// ... existing NewPostsNotifier ...

extension IntExtension on int {
  int coerceAtLeast(int min) => this < min ? min : this;
}

// Keep the same scroll controller provider
final feedScrollControllerProvider = Provider.autoDispose<ScrollController>((ref) {
  return ScrollController();
});

class NewPostsNotifier extends StateNotifier<bool> {
  final FeedRepository _repository;
  final Ref _ref;
  Timer? _timer;
  String? _currentTopId;

  NewPostsNotifier(this._repository, this._ref) : super(false) {
    _startPolling();
  }

  void setLatestId(String id) {
    _currentTopId = id;
    state = false; // Reset state when we have fresh data
  }

  void reset() {
    state = false;
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (state) return;

      try {
        final type = _ref.read(feedTypeProvider);
        List<Post> latestPosts;
        
        if (type == FeedType.campus) {
           latestPosts = await _repository.getCampusFeed();
        } else {
           latestPosts = await _repository.getForYouFeed();
        }

        if (_currentTopId == null) {
           if (latestPosts.isNotEmpty) state = true;
           return;
        }

        if (latestPosts.isNotEmpty && latestPosts.first.id != _currentTopId) {
          state = true;
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

final newPostsProvider = StateNotifierProvider<NewPostsNotifier, bool>((ref) {
  return NewPostsNotifier(ref.watch(feedRepositoryProvider), ref);
});
