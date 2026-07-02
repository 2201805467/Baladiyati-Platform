import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/proposal_entity.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../controllers/proposals_controller.dart';
import '../controllers/proposals_state.dart';
import 'proposal_details_page.dart';
import 'suggest_service_page.dart';

class CitizenProposalsPage extends ConsumerStatefulWidget {
  const CitizenProposalsPage({super.key});

  @override
  ConsumerState<CitizenProposalsPage> createState() =>
      _CitizenProposalsPageState();
}

class _CitizenProposalsPageState extends ConsumerState<CitizenProposalsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(proposalsControllerProvider.notifier)
          .fetchProposals(refresh: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<ProposalsState>(proposalsControllerProvider, (previous, next) {
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

    final state = ref.watch(proposalsControllerProvider);
    final currentUser = ref.watch(profileControllerProvider).user;
    final currentUserId = currentUser?.id;
    final currentUserName = currentUser?.name.trim() ?? '';

    final myProposals = state.proposals
        .where((proposal) => _isMine(proposal, currentUserId, currentUserName))
        .toList();
    final publicProposals = state.proposals
        .where((proposal) =>
            !_isMine(proposal, currentUserId, currentUserName) &&
            proposal.isAccepted)
        .toList()
      ..sort((a, b) => b.votes.compareTo(a.votes));

    if (state.isLoading && state.proposals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.proposals.isEmpty) {
      final emptyTextColor = Theme.of(context).textTheme.bodyMedium?.color;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد مقترحات حالياً',
              style: TextStyle(fontSize: 18, color: emptyTextColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(proposalsControllerProvider.notifier)
                  .fetchProposals(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(proposalsControllerProvider.notifier)
          .fetchProposals(refresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (myProposals.isNotEmpty) ...[
            _buildSectionHeader(
              'مقترحاتي',
              Icons.person_pin_outlined,
              primaryGreen,
            ),
            const SizedBox(height: 12),
            ...myProposals.map(
              (proposal) => _buildProposalCard(
                proposal,
                primaryGreen,
                isDark,
                context,
                currentUserId,
                currentUserName,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (publicProposals.isNotEmpty) ...[
            _buildSectionHeader(
              'المقترحات المقبولة',
              Icons.campaign_outlined,
              primaryGreen,
            ),
            const SizedBox(height: 12),
            ...publicProposals.map(
              (proposal) => _buildProposalCard(
                proposal,
                primaryGreen,
                isDark,
                context,
                currentUserId,
                currentUserName,
              ),
            ),
          ],
          if (state.hasMore && !state.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: TextButton(
                  onPressed: () => ref
                      .read(proposalsControllerProvider.notifier)
                      .fetchProposals(),
                  child: const Text('تحميل المزيد'),
                ),
              ),
            ),
          if (state.isLoading && state.proposals.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProposalCard(
    ProposalEntity proposal,
    Color primaryColor,
    bool isDark,
    BuildContext context,
    int? currentUserId,
    String currentUserName,
  ) {
    final isMine = _isMine(proposal, currentUserId, currentUserName);
    final canVote = proposal.isAccepted && !isMine && !proposal.isExpired;
    final canEditOrDelete = isMine && proposal.isUnderReview;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(proposal.category, primaryColor),
                      _statusChip(proposal.status),
                    ],
                  ),
                ),
                Text(
                  isMine ? 'أنت' : proposal.author,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              proposal.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              proposal.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
            if (proposal.isAccepted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    _getRemainingTime(proposal.expiryDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: proposal.isExpired
                          ? Colors.red
                          : Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 18,
                      color: proposal.isSupported ? primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text('${proposal.votes}'),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.thumb_down_alt_outlined,
                      size: 18,
                      color: proposal.isOpposed ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text('${proposal.opposeVotes}'),
                  ],
                ),
                if (canEditOrDelete)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _openEditPage(context, proposal),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('تعديل'),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(context, proposal),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('حذف'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: canVote
                            ? () => ref
                                  .read(proposalsControllerProvider.notifier)
                                  .toggleVote(proposal.id, voteType: 'support')
                            : null,
                        icon: Icon(
                          proposal.isSupported
                              ? Icons.thumb_up_alt
                              : Icons.thumb_up_off_alt,
                          size: 18,
                        ),
                        label: Text(
                          isMine
                              ? 'مقترحك'
                              : proposal.isSupported
                                  ? 'إلغاء'
                                  : 'إعجاب',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: proposal.isSupported
                              ? primaryColor
                              : Colors.grey[600],
                          backgroundColor: proposal.isSupported
                              ? primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: canVote
                            ? () => ref
                                  .read(proposalsControllerProvider.notifier)
                                  .toggleVote(proposal.id, voteType: 'oppose')
                            : null,
                        icon: Icon(
                          proposal.isOpposed
                              ? Icons.thumb_down_alt
                              : Icons.thumb_down_off_alt,
                          size: 18,
                        ),
                        label: Text(
                          isMine
                              ? 'مقترحك'
                              : proposal.isOpposed
                                  ? 'إلغاء'
                                  : 'لا يعجبني',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: proposal.isOpposed
                              ? Colors.red
                              : Colors.grey[600],
                          backgroundColor: proposal.isOpposed
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProposalDetailsPage(proposal: proposal),
                  ),
                ),
                child: const Text('عرض التفاصيل الكاملة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    var label = status;
    var color = Colors.grey;

    if (status == 'under_review') {
      label = 'تحت المراجعة';
      color = Colors.orange;
    } else if (status == 'accepted') {
      label = 'مقبول';
      color = Colors.green;
    } else if (status == 'rejected') {
      label = 'مرفوض';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _openEditPage(
    BuildContext context,
    ProposalEntity proposal,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SuggestServicePage(proposal: proposal),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ProposalEntity proposal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المقترح'),
        content: Text('هل أنت متأكد من حذف المقترح "${proposal.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(proposalsControllerProvider.notifier)
        .deleteSuggestion(proposal.id);
    if (!mounted || !success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف المقترح بنجاح.')),
    );
  }

  bool _isMine(
    ProposalEntity proposal,
    int? currentUserId,
    String currentUserName,
  ) {
    if (currentUserId != null &&
        proposal.authorId != null &&
        proposal.authorId == currentUserId) {
      return true;
    }

    return currentUserName.isNotEmpty && proposal.author == currentUserName;
  }

  String _getRemainingTime(DateTime expiryDate) {
    final difference = expiryDate.difference(DateTime.now());
    if (difference.isNegative) return 'التصويت مغلق';
    if (difference.inDays > 0) {
      return 'متبقي ${difference.inDays} يوم و ${difference.inHours % 24} ساعة';
    } else if (difference.inHours > 0) {
      return 'متبقي ${difference.inHours} ساعة و ${difference.inMinutes % 60} دقيقة';
    } else {
      return 'متبقي ${difference.inMinutes} دقيقة';
    }
  }
}
