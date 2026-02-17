import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:campus_social_media/features/music/domain/music_track.dart';
import 'package:campus_social_media/features/music/data/music_service.dart';
import 'dart:async';

class MusicSearchSheet extends ConsumerStatefulWidget {
  final ValueChanged<Map<String, String>> onSelected;

  const MusicSearchSheet({super.key, required this.onSelected});

  @override
  ConsumerState<MusicSearchSheet> createState() => _MusicSearchSheetState();
}

class _MusicSearchSheetState extends ConsumerState<MusicSearchSheet> {
  final _searchController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  Timer? _debounce;
  List<MusicTrack> _results = [];
  bool _isLoading = false;
  String? _playingTrackId;

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    final results = await ref.read(musicServiceProvider).searchMusic(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePreview(MusicTrack track) async {
    if (_playingTrackId == track.id) {
      await _audioPlayer.stop();
      setState(() => _playingTrackId = null);
    } else {
      await _audioPlayer.stop();
      if (track.previewUrl.isNotEmpty) {
        await _audioPlayer.play(UrlSource(track.previewUrl));
        setState(() => _playingTrackId = track.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _audioPlayer.stop();
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    'Add Music',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(width: 48), // Balance
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists...',
                  hintStyle: TextStyle(color: theme.hintColor),
                  prefixIcon: Icon(Icons.search, color: theme.hintColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_note_rounded, size: 64, color: theme.hintColor.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('Search for your favorite tracks', style: TextStyle(color: theme.hintColor)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final track = _results[index];
                          final isPlaying = _playingTrackId == track.id;

                          return InkWell(
                            onTap: () {
                              _audioPlayer.stop();
                              widget.onSelected(track.toMetadata());
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                // Album Art with Play Button Overlay
                                GestureDetector(
                                  onTap: () => _togglePreview(track),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(track.albumArtUrl, width: 56, height: 56, fit: BoxFit.cover),
                                      ),
                                      Container(
                                        width: 56, height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(isPlaying ? 0.4 : 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Text Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        track.artist,
                                        style: TextStyle(color: theme.hintColor, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Add Button
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF3897F0)),
                                  onPressed: () {
                                    _audioPlayer.stop();
                                    widget.onSelected(track.toMetadata());
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
