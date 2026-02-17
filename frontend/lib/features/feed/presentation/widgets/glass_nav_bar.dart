import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';

class GlassNavBar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int>? onTap;
  
  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final avatarUrl = currentUser?.avatarUrl;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 60 + MediaQuery.of(context).padding.bottom,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: selectedIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                isSelected: selectedIndex == 0,
                onTap: () => onTap?.call(0),
              ),
              _NavItem(
                icon: selectedIndex == 1 ? Icons.search_rounded : Icons.search,
                isSelected: selectedIndex == 1,
                onTap: () => onTap?.call(1),
              ),
              // Shorts
              _NavItem(
                icon: selectedIndex == 2 ? Icons.play_circle_filled : Icons.play_circle_outline,
                isSelected: selectedIndex == 2,
                onTap: () => onTap?.call(2),
              ),
              _NavItem(
                icon: selectedIndex == 3 ? Icons.mic_rounded : Icons.mic_none_rounded,
                isSelected: selectedIndex == 3,
                onTap: () => onTap?.call(3),
              ),
              // Profile — avatar or fallback icon
              _ProfileNavItem(
                avatarUrl: avatarUrl,
                isSelected: selectedIndex == 4,
                onTap: () => onTap?.call(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 28),
        ],
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final String? avatarUrl;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileNavItem({
    required this.avatarUrl,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatarUrl != null)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: theme.colorScheme.onSurface, width: 1.5)
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(isSelected ? 1.5 : 0),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    fit: BoxFit.cover,
                    width: 28,
                    height: 28,
                    placeholder: (_, __) => Container(
                      color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.person,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            )
          else
            Icon(
              isSelected ? Icons.person_rounded : Icons.person_outline_rounded,
              color: theme.colorScheme.onSurface,
              size: 28,
            ),
        ],
      ),
    );
  }
}
