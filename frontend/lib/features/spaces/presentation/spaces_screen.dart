import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/spaces/presentation/spaces_provider.dart';

class SpacesScreen extends ConsumerWidget {
  const SpacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesList = ref.watch(spacesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spaces')),
      body: spacesList.when(
        data: (spaces) => spaces.isEmpty 
            ? const Center(child: Text('No active spaces right now.'))
            : ListView.builder(
                itemCount: spaces.length,
                itemBuilder: (context, index) {
                  final space = spaces[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.mic)),
                      title: Text(space.title),
                      subtitle: Text('${space.topic} • ${space.participantsCount} listening'),
                      trailing: ElevatedButton(
                        child: const Text('Join'),
                        onPressed: () async {
                          final data = await ref.read(spaceControllerProvider.notifier).joinSpace(space.id);
                          if (data != null && context.mounted) {
                            // Navigate to Active Space with token
                            // Since we can't pass objects easily in URL string without serialization,
                            // we'll pass ID and let the screen resolve or uses 'extra'.
                            context.push('/spaces/active', extra: {
                                'space': space,
                                'token': data['token']
                            }); 
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // Show dialog to create space
          _showCreateSpaceDialog(context, ref);
        },
      ),
      // bottomNavigationBar removed to prevent duplication with ShellRoute
    );
  }

  void _showCreateSpaceDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final topicController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a Space'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: topicController, decoration: const InputDecoration(labelText: 'Topic')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(spaceControllerProvider.notifier)
                  .createSpace(titleController.text, topicController.text);
              if (context.mounted) {
                  Navigator.pop(context);
                  ref.refresh(spacesListProvider); // Refresh list
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
