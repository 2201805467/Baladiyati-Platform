import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/report_entity.dart';
import '../controllers/reports_controller.dart';
import '../controllers/reports_state.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(reportsControllerProvider.notifier).fetchReports(refresh: true),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('بلاغاتي'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(ReportsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'لا توجد بلاغات مسجلة بعد',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(reportsControllerProvider.notifier)
                  .fetchReports(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(reportsControllerProvider.notifier)
          .fetchReports(refresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.reports.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == state.reports.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: state.isLoading
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: () => ref
                            .read(reportsControllerProvider.notifier)
                            .fetchReports(),
                        child: const Text('تحميل المزيد'),
                      ),
              ),
            );
          }
          return _ReportCard(report: state.reports[index]);
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportEntity report;
  const _ReportCard({required this.report});

  Color _statusColor(String status) {
    return switch (status) {
      'تم الحل' => Colors.green,
      'جاري العمل' => Colors.blue,
      _ => Colors.orange,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(report.status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  report.id != null ? '#${report.id}' : 'بلاغ جديد',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                _StatusBadge(label: report.status, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.category_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(report.category,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                if (report.locationAddress != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.locationAddress!,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (report.createdAt != null) ...[
              const Divider(height: 24),
              Text(
                'بتاريخ: ${report.createdAt!.toLocal().toString().split(' ')[0]}',
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
