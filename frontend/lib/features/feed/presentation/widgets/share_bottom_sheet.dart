import 'package:flutter/material.dart';

class ShareBottomSheet extends StatelessWidget {
  final String postId;

  const ShareBottomSheet({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Mock contacts for "Direct Send" look
    final contacts = [
      {'name': 'Alex', 'color': Colors.blue},
      {'name': 'Sam', 'color': Colors.green},
      {'name': 'Jordan', 'color': Colors.purple},
      {'name': 'Casey', 'color': Colors.orange},
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Search/Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                   Icon(Icons.search, color: theme.hintColor),
                   const SizedBox(width: 8),
                   Text('Search', style: TextStyle(color: theme.hintColor)),
                ],
              ),
            ),
          ),

          // Direct Contacts Grid (Instagram style)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: (contact['color'] as Color).withOpacity(0.2),
                        child: Text(
                          (contact['name'] as String)[0],
                          style: TextStyle(color: contact['color'] as Color, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(contact['name'] as String, style: theme.textTheme.labelSmall),
                    ],
                  ),
                );
              },
            ),
          ),
          
          const Divider(),

          // System Share Actions
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy link'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('Share via...'),
            onTap: () {
              Navigator.pop(context);
              // Implement share_plus here
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
