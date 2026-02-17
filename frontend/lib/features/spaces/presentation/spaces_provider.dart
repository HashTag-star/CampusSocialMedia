import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/spaces/data/spaces_repository.dart';
import 'package:campus_social_media/features/spaces/domain/space_entity.dart';

final spacesListProvider = FutureProvider.autoDispose<List<Space>>((ref) async {
  return ref.watch(spacesRepositoryProvider).getSpaces();
});

final spaceControllerProvider = StateNotifierProvider<SpaceController, AsyncValue<void>>((ref) {
  return SpaceController(ref.watch(spacesRepositoryProvider));
});

class SpaceController extends StateNotifier<AsyncValue<void>> {
  final SpacesRepository _repository;

  SpaceController(this._repository) : super(const AsyncData(null));

  Future<void> createSpace(String title, String topic) async {
    state = const AsyncLoading();
    try {
      await _repository.createSpace(title, topic);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<Map<String, dynamic>?> joinSpace(String spaceId) async {
    state = const AsyncLoading();
    try {
      final data = await _repository.joinSpace(spaceId);
      state = const AsyncData(null);
      return data;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
  
  Future<void> endSpace(String spaceId) async {
     state = const AsyncLoading();
    try {
      await _repository.endSpace(spaceId);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
