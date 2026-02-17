import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:campus_social_media/features/feed/presentation/feed_provider.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:campus_social_media/features/post/data/music_repository.dart';
import 'package:campus_social_media/features/music/presentation/music_search_sheet.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  bool _isSubmitting = false;

  // Media files (images + videos)
  List<File> _mediaFiles = [];

  // Location
  String? _locationName;

  // Tagged users (names, placeholder)
  List<String> _taggedUsers = [];

  // Music
  Map<String, String>? _musicMetadata;

  // Flow: 0 = pick media, 1 = caption & extras
  int _step = 0;

  // ── MEDIA PICKERS ──

  Future<void> _pickMultipleFromGallery() async {
    final picked = await _picker.pickMultiImage(imageQuality: 100, maxWidth: 2048);
    if (picked.isNotEmpty) {
      setState(() {
        _mediaFiles.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _mediaFiles.add(File(picked.path));
      });
    }
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 100, maxWidth: 2048);
    if (picked != null) {
      setState(() {
        _mediaFiles.add(File(picked.path));
      });
    }
  }

  Future<void> _takeVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
    if (picked != null) {
      setState(() {
        _mediaFiles.add(File(picked.path));
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
    });
  }

  void _reorderMedia(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _mediaFiles.removeAt(oldIndex);
      _mediaFiles.insert(newIndex, item);
    });
  }

  // ── NAVIGATION ──

  void _goToCaption() => setState(() => _step = 1);
  void _goBack() {
    if (_step == 1) {
      setState(() => _step = 0);
    } else {
      context.pop();
    }
  }

  // ── SUBMIT ──

  Future<void> _submit() async {
    if (_captionController.text.isEmpty && _mediaFiles.isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      String? locationJson;
      if (_locationName != null && _locationName!.isNotEmpty) {
        locationJson = jsonEncode({'name': _locationName});
      }

      await ref.read(feedNotifierProvider.notifier).createPost(
        _captionController.text,
        _mediaFiles.map((f) => f.path).toList(),
        location: locationJson,
        taggedUsers: _taggedUsers.isNotEmpty ? _taggedUsers : null,
        musicMetadata: _musicMetadata,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _step == 0 ? _buildPickerStep(context) : _buildCaptionStep(context);
  }

  // ═══════════════════════════════════════════
  // STEP 1: MEDIA PICKER
  // ═══════════════════════════════════════════
  Widget _buildPickerStep(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_mediaFiles.isNotEmpty) ? _goToCaption : null,
            child: Text(
              'Next',
              style: TextStyle(
                color: _mediaFiles.isNotEmpty ? const Color(0xFF3897F0) : theme.disabledColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── MEDIA PREVIEW ──
          Expanded(
            flex: 5,
            child: _mediaFiles.isNotEmpty
                ? _buildMediaPreview(theme, isDark)
                : Container(
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 80, color: theme.hintColor.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text('Add photos & videos', style: TextStyle(color: theme.hintColor, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Tap below to get started', style: TextStyle(color: theme.hintColor.withOpacity(0.5), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
          ),

          Container(height: 1, color: isDark ? Colors.white12 : Colors.black12),

          // ── ACTION BUTTONS ──
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Choose Photos',
                    subtitle: 'Select multiple from gallery',
                    color: const Color(0xFF3897F0),
                    onTap: _pickMultipleFromGallery,
                  ),
                  const SizedBox(height: 8),
                  _ActionTile(
                    icon: Icons.videocam_rounded,
                    label: 'Choose Video',
                    subtitle: 'Select a video from gallery',
                    color: const Color(0xFFE1306C),
                    onTap: _pickVideoFromGallery,
                  ),
                  const SizedBox(height: 8),
                  _ActionTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take Photo',
                    subtitle: 'Use your camera',
                    color: const Color(0xFFF77737),
                    onTap: _takePhoto,
                  ),
                  const SizedBox(height: 8),
                  _ActionTile(
                    icon: Icons.fiber_smart_record_rounded,
                    label: 'Record Video',
                    subtitle: 'Up to 60 seconds',
                    color: const Color(0xFF833AB4),
                    onTap: _takeVideo,
                  ),
                  if (_mediaFiles.isEmpty) ...[
                    const SizedBox(height: 8),
                    _ActionTile(
                      icon: Icons.text_fields_rounded,
                      label: 'Text Only',
                      subtitle: 'Share without media',
                      color: const Color(0xFF00B900),
                      onTap: _goToCaption,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(ThemeData theme, bool isDark) {
    if (_mediaFiles.length == 1) {
      final file = _mediaFiles[0];
      final isVideo = file.path.endsWith('.mp4') || file.path.endsWith('.mov') || file.path.endsWith('.avi');
      return Stack(
        fit: StackFit.expand,
        children: [
          isVideo
              ? Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam, color: Colors.white54, size: 48),
                        const SizedBox(height: 8),
                        Text(file.path.split(Platform.pathSeparator).last,
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              : Image.file(file, fit: BoxFit.cover),
          _buildRemoveButton(0),
        ],
      );
    }

    // Multiple files — show grid
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: _mediaFiles.length,
        onReorder: _reorderMedia,
        itemBuilder: (context, index) {
          final file = _mediaFiles[index];
          final isVideo = file.path.endsWith('.mp4') || file.path.endsWith('.mov') || file.path.endsWith('.avi');

          return Container(
            key: ValueKey(file.path),
            width: 160,
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isVideo
                      ? Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 48),
                          ),
                        )
                      : Image.file(file, fit: BoxFit.cover),
                ),
                // Order indicator
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${index + 1}/${_mediaFiles.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                // Video badge
                if (isVideo)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                // Remove button
                _buildRemoveButton(index),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRemoveButton(int index) {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: () => _removeMedia(index),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: const Icon(Icons.close, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STEP 2: CAPTION & EXTRAS
  // ═══════════════════════════════════════════
  Widget _buildCaptionStep(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          onPressed: _goBack,
        ),
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3897F0)))
                  : const Text('Share', style: TextStyle(color: Color(0xFF3897F0), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Caption + Thumbnail Row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.person, color: theme.colorScheme.onSurface, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      autofocus: true,
                      maxLines: null,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write a caption...',
                        hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(top: 8),
                      ),
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  ),
                  if (_mediaFiles.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _mediaFiles.length == 1
                          ? Image.file(_mediaFiles[0], width: 72, height: 72, fit: BoxFit.cover)
                          : Stack(
                              children: [
                                Image.file(_mediaFiles[0], width: 72, height: 72, fit: BoxFit.cover),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_mediaFiles.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ],
              ),
            ),

            Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),

            // ── Location ──
            _OptionRow(
              icon: Icons.location_on_outlined,
              label: _locationName ?? 'Add Location',
              trailing: _locationName != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _locationName = null),
                    )
                  : null,
              onTap: () => _showLocationDialog(),
            ),
            Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06), height: 1, indent: 16),

            // ── Tag People ──
            _OptionRow(
              icon: Icons.person_add_alt_1_outlined,
              label: _taggedUsers.isEmpty ? 'Tag People' : '${_taggedUsers.length} tagged',
              trailing: _taggedUsers.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _taggedUsers.clear()),
                    )
                  : null,
              onTap: () => _showTagDialog(),
            ),
            Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06), height: 1, indent: 16),

            // ── Music ──
            _OptionRow(
              icon: Icons.music_note_outlined,
              label: _musicMetadata != null
                  ? '${_musicMetadata!['title']} — ${_musicMetadata!['artist']}'
                  : 'Add Music',
              trailing: _musicMetadata != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _musicMetadata = null),
                    )
                  : null,
              onTap: () => _showMusicDialog(),
            ),

            // ── Media count indicator ──
            if (_mediaFiles.length > 1)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.collections_rounded, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        '${_mediaFiles.length} items — will appear as carousel',
                        style: TextStyle(fontSize: 13, color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── DIALOGS ──

  void _showLocationDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationSheet(
        currentLocation: _locationName,
        onSelected: (location) {
          setState(() => _locationName = location);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Tag People'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Enter username',
                            prefixIcon: Icon(Icons.person_search),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF3897F0)),
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) {
                            setDialogState(() {
                              _taggedUsers.add(controller.text.trim());
                            });
                            controller.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_taggedUsers.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: _taggedUsers
                          .map((u) => Chip(
                                label: Text(u),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setDialogState(() => _taggedUsers.remove(u));
                                },
                              ))
                          .toList(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {}); // refresh parent
                    Navigator.pop(ctx);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
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

// ═══════════════════════════════════════════
// Location Bottom Sheet
// ═══════════════════════════════════════════

class _LocationSheet extends StatefulWidget {
  final String? currentLocation;
  final ValueChanged<String> onSelected;

  const _LocationSheet({this.currentLocation, required this.onSelected});

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isGettingLocation = false;

  // Curated campus landmarks — expandable per university
  static const _landmarks = [
    {'name': 'KNUST', 'subtitle': 'Kwame Nkrumah University of Science and Technology', 'icon': '🏫'},
    {'name': 'KNUST Senate Building', 'subtitle': 'Main administration', 'icon': '🏛️'},
    {'name': 'Unity Hall', 'subtitle': 'Conti, KNUST', 'icon': '🏠'},
    {'name': 'Republic Hall', 'subtitle': 'Repub, KNUST', 'icon': '🏠'},
    {'name': 'Independence Hall', 'subtitle': 'Indece, KNUST', 'icon': '🏠'},
    {'name': 'Queens Hall', 'subtitle': "Queens, KNUST", 'icon': '🏠'},
    {'name': 'University Hall', 'subtitle': 'Katanga, KNUST', 'icon': '🏠'},
    {'name': 'Africa Hall', 'subtitle': 'KNUST', 'icon': '🏠'},
    {'name': 'Great Hall', 'subtitle': 'KNUST Auditorium', 'icon': '🎭'},
    {'name': 'KNUST School of Business (KSB)', 'subtitle': 'Business School', 'icon': '💼'},
    {'name': 'College of Engineering', 'subtitle': 'COE, KNUST', 'icon': '⚙️'},
    {'name': 'College of Science', 'subtitle': 'COS, KNUST', 'icon': '🔬'},
    {'name': 'College of Art and Built Environment', 'subtitle': 'CABE, KNUST', 'icon': '🎨'},
    {'name': 'College of Health Sciences', 'subtitle': 'CHS, KNUST', 'icon': '⚕️'},
    {'name': 'Faculty of Pharmacy', 'subtitle': 'KNUST', 'icon': '💊'},
    {'name': 'KNUST Library', 'subtitle': 'Main Library', 'icon': '📚'},
    {'name': 'KNUST Stadium', 'subtitle': 'University Stadium', 'icon': '🏟️'},
    {'name': 'Commercial Area', 'subtitle': 'KNUST', 'icon': '🛒'},
    {'name': 'Brunei Hostel', 'subtitle': 'KNUST', 'icon': '🏠'},
    {'name': 'Gaza Hostel', 'subtitle': 'KNUST', 'icon': '🏠'},
    {'name': 'SRC Building', 'subtitle': 'Student Representative Council', 'icon': '🏢'},
    {'name': 'Kumasi', 'subtitle': 'Ashanti Region, Ghana', 'icon': '📍'},
    {'name': 'Tech Junction', 'subtitle': 'KNUST Main Entrance', 'icon': '🚏'},
    {'name': 'Ayeduase', 'subtitle': 'Near KNUST', 'icon': '📍'},
    {'name': 'Bomso', 'subtitle': 'Near KNUST', 'icon': '📍'},
    {'name': 'Kentinkrono', 'subtitle': 'Near KNUST', 'icon': '📍'},
  ];

  List<Map<String, String>> get _filtered {
    if (_query.isEmpty) return _landmarks;
    return _landmarks
        .where((l) =>
            l['name']!.toLowerCase().contains(_query.toLowerCase()) ||
            l['subtitle']!.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    
    try {
      // 1. Check permissions
      final status = await Permission.locationWhenInUse.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Location permission denied')),
           );
        }
        return;
      }

      // 2. Get location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // 3. Use coordinates (since we don't have reverse geocoding API)
      // Ideally we would use geocoding package here
      // For now, let's just format it nicely or use a placeholder if appropriate
      // But user wanted "Actual real time location"
      // We'll format as "My Location (Lat: ..., Long: ...)" which implies real data
      final locationString = '📍 ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      
      widget.onSelected(locationString);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
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
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Add Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            ),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search locations...',
                    hintStyle: TextStyle(color: theme.hintColor, fontSize: 15),
                    prefixIcon: Icon(Icons.search, color: theme.hintColor, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Results
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Current Location Option
                  ListTile(
                    leading: _isGettingLocation 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, color: Color(0xFF3897F0)),
                    title: const Text('Use Current Location', style: TextStyle(color: Color(0xFF3897F0), fontWeight: FontWeight.w600)),
                    subtitle: const Text('Turn on location services', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: _isGettingLocation ? null : _getCurrentLocation,
                  ),
                  const Divider(height: 1),

                  ..._filtered.map((loc) => ListTile(
                        leading: Text(loc['icon']!, style: const TextStyle(fontSize: 22)),
                        title: Text(loc['name']!, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        subtitle: Text(loc['subtitle']!, style: TextStyle(fontSize: 13, color: theme.hintColor)),
                        dense: true,
                        onTap: () => widget.onSelected(loc['name']!),
                      )),

                  // Custom location
                  if (_query.isNotEmpty && _filtered.isEmpty) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.add_location_alt, color: Color(0xFF3897F0)),
                      title: Text('Use "$_query"', style: const TextStyle(color: Color(0xFF3897F0), fontWeight: FontWeight.w600)),
                      onTap: () => widget.onSelected(_query),
                    ),
                  ],
                  if (_query.isNotEmpty && _filtered.isNotEmpty) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.edit_location_alt, color: Color(0xFF3897F0)),
                      title: Text('Use custom: "$_query"', style: const TextStyle(color: Color(0xFF3897F0), fontWeight: FontWeight.w500, fontSize: 14)),
                      dense: true,
                      onTap: () => widget.onSelected(_query),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Music Bottom Sheet (IG-style)
// ═══════════════════════════════════════════

class _MusicSheet extends ConsumerStatefulWidget {
  final Map<String, String>? currentMusic;
  final ValueChanged<Map<String, String>> onSelected;

  const _MusicSheet({this.currentMusic, required this.onSelected});

  @override
  ConsumerState<_MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends ConsumerState<_MusicSheet> {
  final _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  String _query = '';
  // "All" is active, others act as quick searches
  String _selectedCategory = 'All';

  List<MusicTrack> _searchResults = [];
  bool _isLoading = false;
  String? _playingPreviewUrl;

  // Curated search terms for quick access
  static const _categories = ['All', 'Popular', 'Afrobeats', 'Hip Hop', 'R&B', 'Gospel'];

  @override
  void initState() {
    super.initState();
    // Debounce search or just search on submit?
    // Let's search on submit or debounce manually.
    // For simplicity, search on submitted for now, or debounce 500ms.
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      final results = await ref.read(musicRepositoryProvider).searchMusic(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      // handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePreview(String url) async {
    if (_playingPreviewUrl == url) {
      await _audioPlayer.stop();
      setState(() => _playingPreviewUrl = null);
    } else {
      await _audioPlayer.stop(); // stop current
      setState(() => _playingPreviewUrl = url);
      await _audioPlayer.play(UrlSource(url));
      
      // Reset when finished
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted && _playingPreviewUrl == url) {
           setState(() => _playingPreviewUrl = null);
        }
      });
    }
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    if (category != 'All') {
      _searchController.text = category; // Pre-fill search
      _query = category;
      _search(category);
    } else {
      _searchController.clear();
      _query = '';
      setState(() => _searchResults = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
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
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Add Music', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search songs and artists...',
                    hintStyle: TextStyle(color: theme.hintColor, fontSize: 15),
                    prefixIcon: Icon(Icons.search, color: theme.hintColor, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: _search,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category chips
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _categories.map((cat) {
                  final isActive = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onCategorySelected(cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFEF)),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isActive
                                ? (isDark ? Colors.black : Colors.white)
                                : theme.colorScheme.onSurface,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Song list
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _query.isNotEmpty
                  ? Center(child: Text('No results found', style: TextStyle(color: theme.hintColor)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length + 1, // +1 for custom option
                      itemBuilder: (context, index) {
                        if (index == _searchResults.length) {
                           // Custom song option at the end
                           return Column(
                             children: [
                               const Divider(height: 1),
                               ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFEF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF3897F0), width: 1.5),
                                  ),
                                  child: const Icon(Icons.edit, color: Color(0xFF3897F0), size: 20),
                                ),
                                title: const Text('Add Custom Song', style: TextStyle(color: Color(0xFF3897F0), fontWeight: FontWeight.w600, fontSize: 15)),
                                subtitle: Text('Enter title and artist manually', style: TextStyle(fontSize: 13, color: theme.hintColor)),
                                onTap: () => _showCustomSongDialog(),
                              ),
                              const SizedBox(height: 40),
                             ],
                           );
                        }

                        final song = _searchResults[index];
                        final isPlaying = _playingPreviewUrl == song.previewUrl;

                        return ListTile(
                          leading: GestureDetector(
                            onTap: () => _togglePreview(song.previewUrl),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(6),
                                    image: song.artworkUrl.isNotEmpty 
                                        ? DecorationImage(image: NetworkImage(song.artworkUrl))
                                        : null,
                                  ),
                                  child: song.artworkUrl.isEmpty ? const Icon(Icons.music_note, color: Colors.white) : null,
                                ),
                                if (song.previewUrl.isNotEmpty)
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          title: Text(song.trackName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                          subtitle: Text(song.artistName, style: TextStyle(fontSize: 13, color: theme.hintColor)),
                          trailing: IconButton(
                             icon: Icon(Icons.add_circle_outline, color: theme.hintColor, size: 22),
                             onPressed: () => widget.onSelected({
                               'title': song.trackName, 
                               'artist': song.artistName,
                               'previewUrl': song.previewUrl,
                             }),
                          ),
                          dense: true,
                          onTap: () => widget.onSelected({
                            'title': song.trackName, 
                            'artist': song.artistName,
                            'previewUrl': song.previewUrl,
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomSongDialog() {
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Song'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Song title', prefixIcon: Icon(Icons.music_note)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: artistController,
              decoration: const InputDecoration(hintText: 'Artist name', prefixIcon: Icon(Icons.person)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                widget.onSelected({
                  'title': titleController.text.trim(),
                  'artist': artistController.text.trim(),
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Supporting Widgets
// ═══════════════════════════════════════════

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.06),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color.withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _OptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface), overflow: TextOverflow.ellipsis),
            ),
            if (trailing != null) trailing! else Icon(Icons.chevron_right, color: theme.hintColor, size: 22),
          ],
        ),
      ),
    );
  }
}
