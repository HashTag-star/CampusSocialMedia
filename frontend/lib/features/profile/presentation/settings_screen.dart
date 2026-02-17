import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';
import 'package:campus_social_media/features/admin/presentation/admin_dashboard_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Account Section
          _SectionHeader(title: 'Account'),
          if (currentUser?.role == 'admin')
            _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin Dashboard',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
              ),
            ),
          _SettingsTile(
            icon: Icons.person_outline,
            label: 'Personal Information',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Password & Security',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.school_outlined,
            label: 'University Verification',
            onTap: () => _showComingSoon(context),
          ),

          const SizedBox(height: 8),

          // Preferences Section
          _SectionHeader(title: 'Preferences'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            label: 'Appearance',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.language,
            label: 'Language',
            trailing: Text('English', style: TextStyle(color: theme.hintColor, fontSize: 14)),
            onTap: () => _showComingSoon(context),
          ),

          const SizedBox(height: 8),

          // Privacy Section
          _SectionHeader(title: 'Privacy'),
          _SettingsTile(
            icon: Icons.visibility_outlined,
            label: 'Account Privacy',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.block_outlined,
            label: 'Blocked Accounts',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.volume_off_outlined,
            label: 'Muted Accounts',
            onTap: () => _showComingSoon(context),
          ),

          const SizedBox(height: 8),

          // Support Section
          _SectionHeader(title: 'Support'),
          _SettingsTile(
            icon: Icons.help_outline,
            label: 'Help Center',
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'About',
            onTap: () => _showComingSoon(context),
          ),

          const SizedBox(height: 16),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log Out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ref.read(authStateProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                        child: const Text('Log Out', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                'Log Out',
                style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).hintColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
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
              child: Text(label, style: const TextStyle(fontSize: 15)),
            ),
            if (trailing != null) trailing! else Icon(Icons.chevron_right, color: theme.hintColor, size: 22),
          ],
        ),
      ),
    );
  }
}
