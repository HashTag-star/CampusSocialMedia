import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/profile/data/profile_repository.dart';

// ───── Profile Data Provider ─────
final profileProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final repository = ref.watch(profileRepositoryProvider);
  if (userId == 'me') {
    return repository.getMyProfile();
  } else {
    return repository.getUserProfile(userId);
  }
});

// ───── Followers / Following ─────
final followersProvider = FutureProvider.family<List<dynamic>, String>((ref, userId) async {
  return ref.watch(profileRepositoryProvider).getFollowers(userId);
});

final followingProvider = FutureProvider.family<List<dynamic>, String>((ref, userId) async {
  return ref.watch(profileRepositoryProvider).getFollowing(userId);
});

// ───── Follow Controller ─────
class FollowController extends StateNotifier<AsyncValue<void>> {
  final ProfileRepository _repository;
  final Ref _ref;

  FollowController(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> toggleFollow(String userId, bool isFollowing) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (isFollowing) {
        await _repository.unfollowUser(userId);
      } else {
        await _repository.followUser(userId);
      }
      _ref.invalidate(profileProvider(userId));
      _ref.invalidate(followersProvider(userId));
      _ref.invalidate(followingProvider(userId));
    });
  }
}

final followControllerProvider = StateNotifierProvider<FollowController, AsyncValue<void>>((ref) {
  return FollowController(ref.watch(profileRepositoryProvider), ref);
});

// ───── Edit Profile Controller ─────
class EditProfileController extends StateNotifier<AsyncValue<void>> {
  final ProfileRepository _repository;
  final Ref _ref;

  EditProfileController(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<bool> saveProfile({
    String? name,
    String? bio,
    String? major,
    String? year,
    List<String>? interests,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateProfile(
        name: name,
        bio: bio,
        major: major,
        year: year,
        interests: interests,
      );
      _ref.invalidate(profileProvider('me'));
    });
    return !state.hasError;
  }
}

final editProfileControllerProvider = StateNotifierProvider<EditProfileController, AsyncValue<void>>((ref) {
  return EditProfileController(ref.watch(profileRepositoryProvider), ref);
});
