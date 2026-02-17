import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:campus_social_media/features/profile/presentation/profile_provider.dart';
import 'package:campus_social_media/features/profile/data/profile_repository.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:campus_social_media/features/auth/domain/user.dart' as auth_user;

class EditProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _majorController;
  late final TextEditingController _yearController;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    final pd = widget.profile['profile_data'] as Map<String, dynamic>? ?? {};
    _nameController = TextEditingController(text: pd['name'] ?? '');
    _bioController = TextEditingController(text: pd['bio'] ?? '');
    _majorController = TextEditingController(text: pd['major'] ?? '');
    _yearController = TextEditingController(text: pd['year'] ?? '');
    _avatarUrl = pd['avatar_url'] as String?;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _majorController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(profileRepositoryProvider).updateAvatar(picked.path);
      // Refresh profile to get the new avatar URL
      ref.invalidate(profileProvider('me'));
      final updatedProfile = await ref.read(profileProvider('me').future);
      final newUrl = (updatedProfile['profile_data'] as Map<String, dynamic>?)?['avatar_url'] as String?;

      if (mounted) {
        setState(() {
          _avatarUrl = newUrl;
          _uploadingAvatar = false;
        });

        // Update currentUserProvider so navbar updates immediately
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          ref.read(currentUserProvider.notifier).state = auth_user.User(
            id: currentUser.id,
            email: currentUser.email,
            avatarUrl: newUrl,
            name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : currentUser.name,
            profileData: {...?currentUser.profileData, 'avatar_url': newUrl},
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final success = await ref.read(editProfileControllerProvider.notifier).saveProfile(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      major: _majorController.text.trim(),
      year: _yearController.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        // Update currentUserProvider
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          ref.read(currentUserProvider.notifier).state = auth_user.User(
            id: currentUser.id,
            email: currentUser.email,
            avatarUrl: _avatarUrl ?? currentUser.avatarUrl,
            name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : currentUser.name,
            profileData: {
              ...?currentUser.profileData,
              'name': _nameController.text.trim(),
              'bio': _bioController.text.trim(),
              'avatar_url': _avatarUrl,
            },
          );
        }
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Done', style: TextStyle(color: Color(0xFF3897F0), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                   GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.dividerColor, width: 1),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: CircleAvatar(
                          radius: 48,
                          backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                          backgroundImage: _avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!) : null,
                          child: _avatarUrl == null
                              ? Icon(Icons.person, size: 48, color: theme.hintColor)
                              : null,
                        ),
                    ),
                  ),
                  if (_uploadingAvatar)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black45,
                        ),
                        child: const Center(
                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        ),
                      ),
                    ),
                  if (!_uploadingAvatar)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3897F0),
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: isDark ? Colors.white12 : Colors.black12),
            _ProfileField(label: 'Name', controller: _nameController),
            _ProfileField(label: 'Bio', controller: _bioController, maxLines: 3),
            _ProfileField(label: 'Major', controller: _majorController),
            _ProfileField(label: 'Year', controller: _yearController),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const _ProfileField({required this.label, required this.controller, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface.withOpacity(0.7))),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF262626) : Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF3897F0), width: 1.5),
              ),
              hintText: 'Enter your $label',
              hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }
}
