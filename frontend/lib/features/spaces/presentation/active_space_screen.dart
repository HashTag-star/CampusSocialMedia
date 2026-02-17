import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/spaces/domain/space_entity.dart';

class ActiveSpaceScreen extends StatelessWidget {
  final Space space;
  final String token; // Mock SFU Token

  const ActiveSpaceScreen({super.key, required this.space, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(space.title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () {
            // Minimize or Leave logic
            context.pop();
          },
        ),
      ),
      body: Column(
        children: [
          // Topic
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              space.topic.toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          
          // Speakers Grid (Mock)
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16),
              children: [
                _buildAvatar(space.host?.email.split('@')[0] ?? 'Host', true),
                _buildAvatar('You', false),
                _buildAvatar('Listener 1', false),
                _buildAvatar('Listener 2', false),
              ],
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.mic_off, color: Colors.white, size: 32),
                  onPressed: () {},
                ),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Leave quietly'),
                ),
                IconButton(
                  icon: const Icon(Icons.handshake, color: Colors.white, size: 32),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, bool isSpeaking) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isSpeaking ? Border.all(color: Colors.green, width: 3) : null,
          ),
          child: const CircleAvatar(
            radius: 32,
            child: Icon(Icons.person, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
