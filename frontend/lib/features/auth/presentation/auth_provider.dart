import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/auth/domain/user.dart';
import 'package:campus_social_media/features/auth/data/auth_repository.dart';
import 'package:campus_social_media/core/network/api_client.dart';
import 'package:campus_social_media/features/profile/presentation/profile_provider.dart';
import 'package:campus_social_media/core/services/storage_service.dart';

final currentUserProvider = StateProvider<User?>((ref) => null);

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.read(storageServiceProvider),
    ref,
  );
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;
  final StorageService _storage;
  final Ref _ref;

  AuthNotifier(this._repository, this._storage, this._ref) : super(const AsyncData(null));

  Future<void> checkAuth() async {
    state = const AsyncLoading();
    try {
      final token = await _storage.read(key: 'auth_token');
      
      if (token == null) {
        state = const AsyncData(null);
        return;
      }

      // Token exists, fetch user data
      try {
        final user = await _repository.getMe();
        _ref.read(currentUserProvider.notifier).state = user;
        state = const AsyncData(null);
      } catch (e) {
        // Token invalid or network error
        await _storage.delete(key: 'auth_token');
        state = const AsyncData(null); // Return to login state
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final response = await _repository.login(email, password);
      await _storage.write(key: 'auth_token', value: response.token);
      
      // Verify write


      // Store current user in provider
      _ref.read(currentUserProvider.notifier).state = response.user;
      
      // Invalidate cached profile so profile screen fetches fresh data
      _ref.invalidate(profileProvider('me'));
      
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> register(String email, String password, String domain) async {
    state = const AsyncLoading();
    try {
      final response = await _repository.register(email, password, domain);
      await _storage.write(key: 'auth_token', value: response.token);
      
      // Store current user in provider
      _ref.read(currentUserProvider.notifier).state = response.user;
      
      // Invalidate cached profile so profile screen fetches fresh data
      _ref.invalidate(profileProvider('me'));
      
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    _ref.read(currentUserProvider.notifier).state = null;
    _ref.invalidate(profileProvider('me'));
    state = const AsyncData(null);
  }
}

