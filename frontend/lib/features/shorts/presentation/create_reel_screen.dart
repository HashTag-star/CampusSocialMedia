import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:campus_social_media/features/feed/presentation/feed_provider.dart';
import 'package:campus_social_media/features/shorts/presentation/shorts_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:campus_social_media/features/music/presentation/music_search_sheet.dart';

class CreateReelScreen extends ConsumerStatefulWidget {
  const CreateReelScreen({super.key});

  @override
  ConsumerState<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends ConsumerState<CreateReelScreen> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();
  File? _videoFile;
  Player? _player;
  VideoController? _videoController;
  bool _isSubmitting = false;
  int _step = 0; // 0 = pick video, 1 = preview + caption

  // Music
  Map<String, String>? _musicMetadata;

  @override
  void dispose() {
    _captionController.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 90),
    );
    if (picked != null) _setVideo(File(picked.path));
  }

  Future<void> _recordVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 90),
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked != null) _setVideo(File(picked.path));
  }

  void _setVideo(File file) {
    _player?.dispose();
    _player = Player();
    _videoController = VideoController(_player!);
    
    _player!.open(Media(file.path), play: true).then((_) {
      if (mounted) {
        _player!.setPlaylistMode(PlaylistMode.loop);
        setState(() {});
      }
    });

    setState(() {
      _videoFile = file;
      _step = 1;
    });
  }

  void _clearVideo() {
    _player?.dispose();
    setState(() {
      _videoFile = null;
      _player = null;
      _videoController = null;
      _step = 0;
    });
  }

  Future<void> _submit() async {
    if (_videoFile == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(feedNotifierProvider.notifier).createPost(
        _captionController.text,
        [_videoFile!.path],
        musicMetadata: _musicMetadata,
      );
      // Refresh shorts feed
      ref.invalidate(shortsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post reel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _step == 0 ? _buildPickerStep(context) : _buildPreviewStep(context);
  }

  // ── Step 0: Pick Video ──
  Widget _buildPickerStep(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Reel',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Big camera icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 32),
            const Text(
              'Create a Reel',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Share short videos with your campus',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 48),

            // Record
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _recordVideo,
                  icon: const Icon(Icons.fiber_manual_record, size: 20),
                  label: const Text('Record Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE1306C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Gallery
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 20),
                  label: const Text('Choose from Gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: Colors.white38, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Videos up to 90 seconds',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Preview + Caption ──
  Widget _buildPreviewStep(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Check initialization indirectly via player existence
    final isReady = _player != null && _videoController != null;
    final isPlaying = _player?.state.playing ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          onPressed: _clearVideo,
        ),
        title: const Text('New Reel',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          _isSubmitting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _submit,
                  child: const Text(
                    'Share',
                    style: TextStyle(color: Color(0xFF3897F0), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Video Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.5,
                width: double.infinity,
                color: Colors.grey[900],
                child: isReady
                    ? GestureDetector(
                        onTap: () {
                          if (_player!.state.playing) {
                            _player!.pause();
                          } else {
                            _player!.play();
                          }
                          setState(() {});
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.width, // Approximate aspect ratio container
                                child: Video(
                                    controller: _videoController!,
                                    fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (!isPlaying)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                                ),
                              ),
                            // Duration badge
                            if (_player != null && _player!.state.duration.inSeconds > 0)
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatDuration(_player!.state.duration),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : const Center(child: CircularProgressIndicator(color: Colors.white54)),
              ),
            ),

            const SizedBox(height: 20),

            // Caption
            TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 16),

            // Add Music
            _OptionTile(
              icon: Icons.music_note_rounded,
              label: _musicMetadata != null
                  ? '${_musicMetadata!['title']} • ${_musicMetadata!['artist']}'
                  : 'Add Music',
              onTap: () => _showMusicDialog(),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _showMusicDialog() {
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

// ── Option Tile ──
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }
}
