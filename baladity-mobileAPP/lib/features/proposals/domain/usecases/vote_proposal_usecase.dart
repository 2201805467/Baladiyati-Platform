import '../entities/proposal_entity.dart';
import '../repositories/proposals_repository.dart';

class VoteProposalUseCase {
  final ProposalsRepository _repository;
  VoteProposalUseCase(this._repository);

  Future<ProposalEntity> call(String proposalId, {required bool currentlyVoted}) =>
      currentlyVoted
          ? _repository.unvote(proposalId)
          : _repository.vote(proposalId);
}
