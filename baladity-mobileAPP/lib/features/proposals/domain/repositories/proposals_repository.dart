import '../entities/proposal_entity.dart';

abstract class ProposalsRepository {
  Future<List<ProposalEntity>> getProposals({int page = 1, bool mine = false});
  Future<ProposalEntity> vote(String proposalId, {required String voteType});
  Future<ProposalEntity> unvote(String proposalId);
  Future<void> suggestProposal({
    required String title,
    required String category,
    required String description,
  });
  Future<ProposalEntity> updateProposal({
    required String proposalId,
    required String title,
    required String category,
    required String description,
  });
  Future<void> deleteProposal(String proposalId);
}
