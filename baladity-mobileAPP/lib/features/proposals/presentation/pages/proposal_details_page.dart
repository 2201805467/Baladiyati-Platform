import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../domain/entities/proposal_entity.dart';
import '../controllers/proposals_controller.dart';

class ProposalDetailsPage extends ConsumerWidget {
  final ProposalEntity proposal;
  const ProposalDetailsPage({super.key, required this.proposal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryGreen = Color(0xFF2E7D32);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = Theme.of(context).textTheme.bodySmall?.color;
    final currentUser = ref.watch(profileControllerProvider).user;
    final currentUserId = currentUser?.id;
    final currentUserName = currentUser?.name.trim() ?? '';

    final latest = ref.watch(
      proposalsControllerProvider.select(
        (s) =>
            s.proposals.where((p) => p.id == proposal.id).firstOrNull ??
            proposal,
      ),
    );
    final isMine =
        (currentUserId != null &&
            latest.authorId != null &&
            latest.authorId == currentUserId) ||
        (currentUserName.isNotEmpty && latest.author == currentUserName);
    final canVote = latest.isAccepted && !isMine && !latest.isExpired;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  latest.category,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                latest.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.person_pin_circle_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'صاحب المقترح: ${isMine ? 'أنت' : latest.author}',
                    style: TextStyle(color: mutedColor),
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
                style: TextStyle(
                  fontSize: 16,
                  height: 1.8,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
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
                      _buildStatItem('إعجاب', '${latest.votes}', primaryGreen),
                      const VerticalDivider(),
                      _buildStatItem(
                        'عدم إعجاب',
                        '${latest.opposeVotes}',
                        Colors.red,
                      ),
                      const VerticalDivider(),
                      _buildStatItem(
                        'حالة التصويت',
                        latest.isExpired
                            ? 'مغلق'
                            : isMine
                            ? 'مقترحك'
                            : latest.isSupported
                            ? 'معجب'
                            : latest.isOpposed
                            ? 'غير معجب'
                            : 'نشط',
                        latest.isExpired
                            ? Colors.red
                            : isMine
                            ? Colors.grey
                            : Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!latest.isExpired)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canVote
                            ? () => ref
                                  .read(proposalsControllerProvider.notifier)
                                  .toggleVote(latest.id, voteType: 'support')
                            : null,
                        icon: Icon(
                          latest.isSupported
                              ? Icons.thumb_up_alt
                              : Icons.thumb_up_off_alt,
                        ),
                        label: Text(
                          isMine
                              ? 'مقترحك'
                              : latest.isSupported
                              ? 'إلغاء الإعجاب'
                              : 'إعجاب',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: latest.isSupported
                              ? (isDark ? Colors.grey[800] : Colors.grey[300])
                              : primaryGreen,
                          foregroundColor: latest.isSupported
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canVote
                            ? () => ref
                                  .read(proposalsControllerProvider.notifier)
                                  .toggleVote(latest.id, voteType: 'oppose')
                            : null,
                        icon: Icon(
                          latest.isOpposed
                              ? Icons.thumb_down_alt
                              : Icons.thumb_down_off_alt,
                        ),
                        label: Text(
                          isMine
                              ? 'مقترحك'
                              : latest.isOpposed
                              ? 'إلغاء عدم الإعجاب'
                              : 'لا يعجبني',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: latest.isOpposed
                              ? Colors.red
                              : Colors.grey[700],
                          side: BorderSide(
                            color: latest.isOpposed
                                ? Colors.red
                                : Colors.grey.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
