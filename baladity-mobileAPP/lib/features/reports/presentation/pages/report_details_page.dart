import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_constants.dart';
import '../../domain/entities/report_comment_entity.dart';
import '../../domain/entities/report_entity.dart';
import '../controllers/reports_controller.dart';
import '../controllers/reports_state.dart';

String _apiOrigin() {
  final baseUrl = ApiConstants.baseUrl;
  if (baseUrl.endsWith('/api/')) {
    return baseUrl.substring(0, baseUrl.length - 5);
  }
  if (baseUrl.endsWith('/api')) {
    return baseUrl.substring(0, baseUrl.length - 4);
  }
  return baseUrl;
}

class ReportDetailsPage extends ConsumerStatefulWidget {
  const ReportDetailsPage({super.key, required this.report});

  final ReportEntity report;

  @override
  ConsumerState<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends ConsumerState<ReportDetailsPage> {
  final _commentController = TextEditingController();
  final _ratingCommentController = TextEditingController();
  int? _selectedRating;

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
    _ratingCommentController.dispose();
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

  Future<void> _submitRating(ReportEntity report) async {
    final id = report.id;
    final stars = _selectedRating ?? report.ratingStars;
    if (id == null || stars == null) return;

    final success = await ref
        .read(reportsControllerProvider.notifier)
        .submitRating(
          reportId: id,
          stars: stars,
          comment: _ratingCommentController.text,
        );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ تقييمك بنجاح')));
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
        child:
            state.isLoadingDetails
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
                      if (_isClosed(report.status) &&
                          (report.completionImageUrl != null ||
                              report.completionReport != null)) ...[
                        const SizedBox(height: 16),
                        _CompletionEvidenceSection(report: report),
                      ],
                      if (_isClosed(report.status)) ...[
                        const SizedBox(height: 16),
                        _RatingSection(
                          currentStars: _selectedRating ?? report.ratingStars,
                          existingComment: report.ratingComment,
                          controller: _ratingCommentController,
                          isSubmitting: state.isSubmittingRating,
                          onStarSelected: (stars) {
                            setState(() => _selectedRating = stars);
                          },
                          onSubmit:
                              (_selectedRating ?? report.ratingStars) == null
                                  ? null
                                  : () => _submitRating(report),
                        ),
                      ],
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

  bool _isClosed(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'closed' ||
        normalized.contains('مغلق') ||
        normalized.contains('تم الحل');
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
              text:
                  report.description.isEmpty ? 'بدون وصف' : report.description,
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

    final base = _apiOrigin();
    return value.startsWith('/') ? '$base$value' : '$base/$value';
  }
}

class _CompletionEvidenceSection extends StatelessWidget {
  const _CompletionEvidenceSection({required this.report});

  final ReportEntity report;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _absoluteImageUrl(report.completionImageUrl);
    final completionReport = report.completionReport?.trim();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'نتيجة الإنجاز',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (completionReport != null && completionReport.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(completionReport),
            ],
            if (imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) => Container(
                        height: 120,
                        alignment: Alignment.center,
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        child: const Text('تعذر تحميل صورة الإنجاز'),
                      ),
                ),
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

    final base = _apiOrigin();
    return value.startsWith('/') ? '$base$value' : '$base/$value';
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.currentStars,
    required this.existingComment,
    required this.controller,
    required this.isSubmitting,
    required this.onStarSelected,
    required this.onSubmit,
  });

  final int? currentStars;
  final String? existingComment;
  final TextEditingController controller;
  final bool isSubmitting;
  final ValueChanged<int> onStarSelected;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    if (controller.text.isEmpty && existingComment?.isNotEmpty == true) {
      controller.text = existingComment!;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تقييم الخدمة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              currentStars == null
                  ? 'اختر عدد النجوم لتقييم جودة معالجة البلاغ'
                  : 'تقييمك الحالي: $currentStars من 5',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;
                final selected = currentStars != null && star <= currentStars!;
                return IconButton(
                  onPressed: isSubmitting ? null : () => onStarSelected(star),
                  icon: Icon(
                    selected ? Icons.star : Icons.star_border,
                    color: selected ? Colors.amber : Colors.grey,
                    size: 34,
                  ),
                  tooltip: '$star نجوم',
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              enabled: !isSubmitting,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'تعليق اختياري حول جودة الخدمة...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon:
                    isSubmitting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.star_rate),
                label: const Text('حفظ التقييم'),
              ),
            ),
          ],
        ),
      ),
    );
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
                icon:
                    isSubmitting
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
