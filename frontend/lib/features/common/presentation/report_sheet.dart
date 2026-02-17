import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/features/feed/data/feed_repository.dart';
import 'package:go_router/go_router.dart';

class ReportSheet extends ConsumerStatefulWidget {
  final String targetType; // 'post', 'comment', 'user'
  final String targetId;

  const ReportSheet({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  String? _selectedReason;
  bool _isLoading = false;

  final List<String> _reasons = [
    'Spam',
    'Harassment or Hate Speech',
    'Nudity or Sexual Activity',
    'False Information',
    'Violence or Dangerous Organizations',
    'Scam or Fraud',
    'Intellectual Property Violation',
    'Other'
  ];

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(feedRepositoryProvider).reportContent(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _selectedReason!,
      );

      if (mounted) {
        context.pop(); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for reporting. We will review this shortly.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to report: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Text(
            'Report ${widget.targetType}',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Why are you reporting this?',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),

          // Reasons List
          ..._reasons.map((reason) => RadioListTile<String>(
            title: Text(reason),
            value: reason,
            groupValue: _selectedReason,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() => _selectedReason = value);
            },
          )),

          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedReason != null && !_isLoading ? _submitReport : null,
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Text('Submit Report'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
