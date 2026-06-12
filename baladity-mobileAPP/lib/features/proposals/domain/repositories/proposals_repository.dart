import '../entities/proposal_entity.dart';

abstract class ProposalsRepository {
  Future<List<ProposalEntity>> getProposals({int page = 1});
  Future<ProposalEntity> vote(String proposalId);
  Future<ProposalEntity> unvote(String proposalId);
  Future<void> suggestProposal({
    required String title,
    required String category,
    required String description,
  });
}
