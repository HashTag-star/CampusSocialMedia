import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/shorts/presentation/shorts_provider.dart';
import 'package:campus_social_media/features/shorts/presentation/reel_viewer_screen.dart';

class ShortsScreen extends ConsumerWidget {
  const ShortsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortsAsync = ref.watch(shortsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: shortsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              const Text('Could not load shorts', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(shortsProvider),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.play_circle_outline_rounded, size: 64, color: Colors.white54),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Shorts Yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload a video to get started!',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ReelViewerScreen(posts: posts, showBackButton: true);
        },
      ),
    );
  }
}
