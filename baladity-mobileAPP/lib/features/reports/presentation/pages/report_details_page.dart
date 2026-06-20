import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_constants.dart';
import '../../domain/entities/report_comment_entity.dart';
import '../../domain/entities/report_entity.dart';
import '../controllers/reports_controller.dart';
import '../controllers/reports_state.dart';

class ReportDetailsPage extends ConsumerStatefulWidget {
  const ReportDetailsPage({super.key, required this.report});

  final ReportEntity report;

  @override
  ConsumerState<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends ConsumerState<ReportDetailsPage> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final id = widget.report.id;
      if (id != null) {
        ref.read(reportsControllerProvider.notifier).fetchReportDetails(id);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment(ReportEntity report) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final id = report.id;
    if (id == null) return;

    final success = await ref
        .read(reportsControllerProvider.notifier)
        .addComment(reportId: id, text: text);

    if (!mounted) return;
    if (success) {
      _commentController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال التعليق بنجاح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReportsState>(reportsControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    });

    final state = ref.watch(reportsControllerProvider);
    final selected = state.selectedReport;
    final report = selected?.id == widget.report.id ? selected! : widget.report;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل البلاغ'), centerTitle: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: state.isLoadingDetails
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  final id = report.id;
                  if (id != null) {
                    await ref
                        .read(reportsControllerProvider.notifier)
                        .fetchReportDetails(id);
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ReportSummary(report: report),
                    const SizedBox(height: 16),
                    _CommentsSection(
                      comments: report.comments,
                      controller: _commentController,
                      isSubmitting: state.isSubmittingComment,
                      onSend: () => _sendComment(report),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final ReportEntity report;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;
    final imageUrl = _absoluteImageUrl(report.imageUrl);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.id == null ? 'بلاغ' : 'بلاغ #${report.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(label: report.status),
              ],
            ),
            const SizedBox(height: 12),
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _InfoRow(icon: Icons.category_outlined, text: report.category),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.description_outlined,
              text: report.description.isEmpty
                  ? 'بدون وصف'
                  : report.description,
            ),
            if (report.locationAddress != null &&
                report.locationAddress!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: report.locationAddress!,
              ),
            ],
            if (report.createdAt != null) ...[
              const Divider(height: 24),
              Text(
                'بتاريخ: ${report.createdAt!.toLocal().toString().split(' ')[0]}',
                style: TextStyle(color: mutedColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _absoluteImageUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http')) return value;

    final base = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return value.startsWith('/') ? '$base$value' : '$base/$value';
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.comments,
    required this.controller,
    required this.isSubmitting,
    required this.onSend,
  });

  final List<ReportCommentEntity> comments;
  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التعليقات والمناقشة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (comments.isEmpty)
              Text(
                'لا توجد تعليقات بعد',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              )
            else
              ...comments.map((comment) => _CommentTile(comment: comment)),
            const Divider(height: 28),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              enabled: !isSubmitting,
              decoration: const InputDecoration(
                hintText: 'اكتب تعليقك هنا...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onSend,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('إرسال التعليق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final ReportCommentEntity comment;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${comment.authorName} - ${comment.authorRole}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (comment.createdAt != null)
                    Text(
                      _formatDate(comment.createdAt!),
                      style: TextStyle(fontSize: 12, color: mutedColor),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(comment.text),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final datePart = local.toString().split('.').first;
    final end = datePart.length < 16 ? datePart.length : 16;
    return datePart.substring(0, end);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.green,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
