import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedAudioProvider = StateNotifierProvider<FeedAudioNotifier, bool>((ref) {
  return FeedAudioNotifier();
});

class FeedAudioNotifier extends StateNotifier<bool> {
  // Start muted by default (like Instagram)
  FeedAudioNotifier() : super(true);

  void toggleMute() {
    state = !state;
  }

  void setMuted(bool isMuted) {
    state = isMuted;
  }
}
