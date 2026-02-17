import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:campus_social_media/features/stories/data/story_repository.dart';
import 'package:campus_social_media/features/feed/data/feed_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:campus_social_media/features/music/presentation/music_search_sheet.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  File? _selectedImage;
  bool _isUploading = false;
  final TextEditingController _captionController = TextEditingController();
  Map<String, String>? _musicMetadata;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _postStory() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);
    try {
      await ref.read(feedRepositoryProvider).createStory(
        _selectedImage!.path,
        caption: _captionController.text.trim(),
        musicMetadata: _musicMetadata,
      );
      if (mounted) {
        context.pop(); // Close screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post story: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedImage == null) {
      // "Camera Mode" / Empty State
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Close Button
            Positioned(
              top: 50,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => context.pop(),
              ),
            ),
            
            // Center content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt, color: Colors.white54, size: 60),
                  const SizedBox(height: 20),
                  Text(
                    'Tap below to choose a photo',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                  ),
                ],
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery Button
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.photo_library, color: Colors.white),
                    ),
                  ),
                  
                  // Shutter Button (Camera)
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  
                  // Spacer to balance layout
                  const SizedBox(width: 50),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // "Preview Mode"
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // Prevent image resize when keyboard opens
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image Preview
          Image.file(_selectedImage!, fit: BoxFit.contain),

          // Close / Discard
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => setState(() => _selectedImage = null),
            ),
          ),

          // Music Button
          Positioned(
            top: 50,
            right: 16,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                ),
                child: GestureDetector(
                    onTap: _showMusicSheet,
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            const Icon(Icons.music_note, color: Colors.white, size: 20),
                            if (_musicMetadata != null) ...[
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 120),
                                    child: Text(
                                        _musicMetadata!['title']!,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                ),
                            ]
                        ],
                    ),
                ),
            ),
          ),

          // Caption Input (Overlay)
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 100,
            left: 32,
            right: 32,
            child: TextField(
              controller: _captionController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3.0,
                    color: Colors.black,
                  ),
                ],
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3.0,
                      color: Colors.black,
                    ),
                  ],
                ),
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: null,
            ),
          ),

          // Post Button
          Positioned(
            bottom: 40,
            right: 16,
            child: GestureDetector(
              onTap: _isUploading ? null : _postStory,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Row(
                        children: [
                          Text('Your Story', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showMusicSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicSearchSheet(
        onSelected: (music) {
          setState(() => _musicMetadata = music);
          Navigator.pop(context);
        },
      ),
    );
  }
}
