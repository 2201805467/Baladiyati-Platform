import '../repositories/proposals_repository.dart';

class DeleteProposalUseCase {
  final ProposalsRepository _repository;
  DeleteProposalUseCase(this._repository);

  Future<void> call(String proposalId) => _repository.deleteProposal(proposalId);
}
