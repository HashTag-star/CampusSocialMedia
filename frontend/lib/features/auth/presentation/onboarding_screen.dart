import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:campus_social_media/features/profile/data/profile_repository.dart';
import 'package:campus_social_media/features/auth/domain/user.dart';

// State provider for onboarding step
final onboardingStepProvider = StateProvider<int>((ref) => 0);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Profile Data
  File? _avatarFile;
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _majorController = TextEditingController();
  final _yearController = TextEditingController();
  
  final List<String> _selectedInterests = [];
  final List<String> _selectedUsersToFollow = [];
  
  // Hardcoded interests
  final List<String> _allInterests = [
    'Computer Science', 'Economics', 'Art', 'Music', 
    'Sports', 'Photography', 'Business', 'Politics',
    'Gaming', 'Startups', 'Design', 'Food'
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(onboardingStepProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress
            LinearProgressIndicator(
              value: (step + 1) / 3, 
              backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
            
            Expanded(
              child: IndexedStack(
                index: step,
                children: [
                  _buildProfileSetup(theme),
                  _buildInterestSelection(theme),
                  _buildSuggestedFollows(theme),
                ],
              ),
            ),

            // Bottom Bar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (step > 0)
                    TextButton(
                      onPressed: () => ref.read(onboardingStepProvider.notifier).state--,
                      child: const Text('Back'),
                    )
                  else
                     const SizedBox(width: 48), // Spacer

                  ElevatedButton(
                    onPressed: () async {
                      if (step == 0) {
                        // Save Profile
                        if (_nameController.text.isNotEmpty) {
                           await ref.read(profileRepositoryProvider).updateProfile(
                             name: _nameController.text,
                             bio: _bioController.text,
                             major: _majorController.text,
                             year: _yearController.text,
                           );
                        }
                        if (_avatarFile != null) {
                           await ref.read(profileRepositoryProvider).updateAvatar(_avatarFile!.path);
                        }
                        ref.read(onboardingStepProvider.notifier).state++;
                      } else if (step == 1) {
                        // Save interests
                        if (_selectedInterests.isNotEmpty) {
                           await ref.read(profileRepositoryProvider).updateProfile(
                             interests: _selectedInterests
                           );
                        }
                        ref.read(onboardingStepProvider.notifier).state++;
                      } else {
                        // Follow users & Finish
                        for (final userId in _selectedUsersToFollow) {
                           await ref.read(profileRepositoryProvider).followUser(userId);
                        }
                        if (mounted) context.go('/feed');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(step == 2 ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSetup(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Set up your profile', 
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          Text(
            'Let others know who you are.', 
             style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 32),

          // Avatar Picker
          GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
              child: _avatarFile == null 
                  ? Icon(Icons.add_a_photo_rounded, size: 40, color: theme.colorScheme.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text('Change Profile Photo', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          
          const SizedBox(height: 32),

          // Fields
          _buildTextField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField(controller: _bioController, label: 'Bio', icon: Icons.info_outline),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField(controller: _majorController, label: 'Major', icon: Icons.school_outlined)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(controller: _yearController, label: 'Year (e.g. 2026)', icon: Icons.calendar_today_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      ),
    );
  }

  Widget _buildInterestSelection(ThemeData theme) {
     return SingleChildScrollView(
       padding: const EdgeInsets.all(24),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text('What are you interested in?', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           Text('We will customize your feed based on your interests.', style: theme.textTheme.bodyLarge),
           const SizedBox(height: 32),
           
           Wrap(
             spacing: 12,
             runSpacing: 12,
             children: _allInterests.map((interest) {
               final isSelected = _selectedInterests.contains(interest);
               return FilterChip(
                 label: Text(interest),
                 selected: isSelected,
                 onSelected: (selected) {
                   setState(() {
                     if (selected) {
                       _selectedInterests.add(interest);
                     } else {
                       _selectedInterests.remove(interest);
                     }
                   });
                 },
                 checkmarkColor: Colors.white,
                 selectedColor: theme.colorScheme.primary,
                 labelStyle: TextStyle(
                   color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color
                 ),
                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
               );
             }).toList(),
           ),
         ],
       ),
     );
  }

  Widget _buildSuggestedFollows(ThemeData theme) {
    // We should fetch this from backend using a FutureProvider
    return Consumer(
      builder: (context, ref, _) {
        final suggestionsAsync = ref.watch(suggestedUsersProvider);

        return suggestionsAsync.when(
          data: (users) {
            if (users.isEmpty) {
               return const Center(child: Text('No suggestions found.'));
            }

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Follow people you might know', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isSelected = _selectedUsersToFollow.contains(user.id);
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                             backgroundImage: NetworkImage(user.profileData?['avatar_url'] ?? 'https://i.pravatar.cc/150?u=${user.id}'),
                          ),
                          title: Text(user.profileData?['name'] ?? user.email.split('@')[0]),
                          subtitle: Text(user.profileData?['bio'] ?? 'Student'),
                          trailing: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUsersToFollow.remove(user.id);
                                } else {
                                  _selectedUsersToFollow.add(user.id);
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
                              foregroundColor: isSelected ? Colors.white : theme.colorScheme.primary,
                              side: BorderSide(color: theme.colorScheme.primary),
                            ),
                            child: Text(isSelected ? 'Following' : 'Follow'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading suggestions: $err')),
        );
      },
    );
  }
}

// Provider to fetch suggestions
final suggestedUsersProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getSuggestedUsers();
});
