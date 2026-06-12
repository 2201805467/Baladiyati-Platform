import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/proposal_entity.dart';
import '../controllers/proposals_controller.dart';
import '../controllers/proposals_state.dart';
import 'proposal_details_page.dart';

class CitizenProposalsPage extends ConsumerStatefulWidget {
  const CitizenProposalsPage({super.key});

  @override
  ConsumerState<CitizenProposalsPage> createState() =>
      _CitizenProposalsPageState();
}

class _CitizenProposalsPageState extends ConsumerState<CitizenProposalsPage> {
  // The current logged-in user's name — will come from AuthState in a real app.
  static const String _currentUser = 'أحمد';

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

    if (state.isLoading && state.proposals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.proposals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('لا توجد مقترحات حالياً',
                style: TextStyle(fontSize: 18, color: Colors.black54)),
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

    final myProposals = state.proposals
        .where((p) => p.author == _currentUser)
        .toList();
    final allSorted = [...state.proposals]
      ..sort((a, b) => b.votes.compareTo(a.votes));

    return RefreshIndicator(
      onRefresh: () => ref
          .read(proposalsControllerProvider.notifier)
          .fetchProposals(refresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (myProposals.isNotEmpty) ...[
            _buildSectionHeader(
                'مقترحاتي', Icons.person_pin_outlined, primaryGreen),
            const SizedBox(height: 12),
            ...myProposals.map((p) =>
                _buildProposalCard(p, primaryGreen, isDark, context)),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader(
              'كل مقترحات المواطنين', Icons.campaign_outlined, primaryGreen),
          const SizedBox(height: 12),
          ...allSorted.map(
              (p) => _buildProposalCard(p, primaryGreen, isDark, context)),
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
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildProposalCard(
    ProposalEntity proposal,
    Color primaryColor,
    bool isDark,
    BuildContext context,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    proposal.category,
                    style: TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  proposal.author == _currentUser ? 'أنت' : proposal.author,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(proposal.title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  _getRemainingTime(proposal.expiryDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: proposal.isExpired ? Colors.red : Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.how_to_vote,
                        size: 20,
                        color: proposal.isVoted ? primaryColor : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${proposal.votes} أصوات',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: proposal.isVoted ? primaryColor : null),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: proposal.isExpired
                      ? null
                      : () => ref
                          .read(proposalsControllerProvider.notifier)
                          .toggleVote(proposal.id,
                              currentlyVoted: proposal.isVoted),
                  icon: Icon(
                    proposal.isVoted
                        ? Icons.thumb_up_alt
                        : Icons.thumb_up_off_alt,
                    size: 18,
                  ),
                  label: Text(proposal.isVoted ? 'إلغاء التصويت' : 'تصويت'),
                  style: TextButton.styleFrom(
                    foregroundColor: proposal.isVoted
                        ? primaryColor
                        : Colors.grey[600],
                    backgroundColor: proposal.isVoted
                        ? primaryColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
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
                    builder: (_) =>
                        ProposalDetailsPage(proposal: proposal),
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
