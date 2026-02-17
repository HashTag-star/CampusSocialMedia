import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/admin/data/admin_repository.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late Future<List<dynamic>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _reportsFuture = ref.read(adminRepositoryProvider).getReports();
    });
  }

  Future<void> _handleAction(String reportId, String action, {String? userId}) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      
      if (action == 'ban' && userId != null) {
        await repo.banUser(userId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User banned')));
      } else {
        await repo.resolveReport(reportId, action); // 'resolved' or 'dismissed'
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report $action')));
      }
      
      _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(child: Text('No pending reports. Great job!'));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final reporter = report['reporter'];
              final createdAt = DateTime.tryParse(report['createdAt']) ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Chip(
                            label: Text(report['target_type'].toString().toUpperCase()),
                            backgroundColor: Colors.red.withOpacity(0.1),
                            labelStyle: const TextStyle(color: Colors.red),
                          ),
                          Text(timeago.format(createdAt)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Reason: ${report['reason']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (report['description'] != null)
                        Text('Details: ${report['description']}'),
                      const SizedBox(height: 8),
                      Text('Reported by: ${reporter != null ? reporter['email'] : 'Unknown'}'),
                      Text('Target ID: ${report['target_id']}'),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _handleAction(report['id'], 'dismissed'),
                            child: const Text('Dismiss'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _handleAction(report['id'], 'resolved'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Resolve'),
                          ),
                          const SizedBox(width: 8),
                          if (report['target_type'] == 'user' || report['target_type'] == 'post') // Can ban user from post report? Logic needed.
                             // For simplicity, let's just allow banning if target_type is user for now, or if we can extract user_id from post.
                             // Backend getReports currently doesn't include target details fully, so banning from post report is hard without extra API call.
                             // Let's hide Ban button for non-user reports for MVP
                             
                             if (report['target_type'] == 'user')
                                OutlinedButton(
                                  onPressed: () => _handleAction(report['id'], 'ban', userId: report['target_id']),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('BAN USER'),
                                )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
