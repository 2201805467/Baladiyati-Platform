import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/proposal_entity.dart';
import '../controllers/proposals_controller.dart';

class ProposalDetailsPage extends ConsumerWidget {
  final ProposalEntity proposal;
  const ProposalDetailsPage({super.key, required this.proposal});

  static const String _currentUser = 'أحمد';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryGreen = Color(0xFF2E7D32);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Always read the latest state for this proposal from the provider
    final latest = ref.watch(
      proposalsControllerProvider.select(
        (s) => s.proposals.where((p) => p.id == proposal.id).firstOrNull ??
            proposal,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المقترح'), centerTitle: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  latest.category,
                  style: const TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                latest.title,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_pin_circle_outlined,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'صاحب المقترح: ${latest.author == _currentUser ? 'أنت' : latest.author}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const Divider(height: 40),
              const Text(
                'وصف المشروع المقترح:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                latest.description,
                style: const TextStyle(
                    fontSize: 16, height: 1.8, color: Colors.black87),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('عدد الأصوات', '${latest.votes}',
                          primaryGreen),
                      const VerticalDivider(),
                      _buildStatItem(
                        'حالة التصويت',
                        latest.isExpired ? 'مغلق' : 'نشط',
                        latest.isExpired ? Colors.red : Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!latest.isExpired)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => ref
                        .read(proposalsControllerProvider.notifier)
                        .toggleVote(latest.id,
                            currentlyVoted: latest.isVoted),
                    icon: Icon(latest.isVoted
                        ? Icons.thumb_up_alt
                        : Icons.thumb_up_off_alt),
                    label: Text(
                        latest.isVoted ? 'إلغاء التصويت' : 'تصويت لهذا المقترح'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: latest.isVoted
                          ? Colors.grey[300]
                          : primaryGreen,
                      foregroundColor: latest.isVoted
                          ? Colors.black87
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
