import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService();
});

class FeedbackService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Initialize sounds if needed (optional)
  Future<void> init() async {
    // heavy initialization could go here
  }

  // Haptics
  Future<void> vibrateLight() async {
    await HapticFeedback.lightImpact();
  }

  Future<void> vibrateMedium() async {
    await HapticFeedback.mediumImpact();
  }

  Future<void> vibrateHeavy() async {
    await HapticFeedback.heavyImpact();
  }

  Future<void> vibrateSuccess() async {
    await HapticFeedback.mediumImpact(); // Customize as needed
  }

  Future<void> vibrateError() async {
    await HapticFeedback.vibrate();
  }

  // Sounds
  Future<void> playSuccessSound() async {
    // For now, using a system sound or placeholder. 
    // In a real app, you'd add assets/sounds/success.mp3
    // await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    
    // Fallback visual/haptic since we don't have assets handy right now
    await vibrateSuccess();
  }

  Future<void> playLikeSound() async {
    // await _audioPlayer.play(AssetSource('sounds/pop.mp3'));
    await vibrateLight();
  }
}
