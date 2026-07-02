import '../entities/proposal_entity.dart';
import '../repositories/proposals_repository.dart';

class UpdateProposalUseCase {
  final ProposalsRepository _repository;
  UpdateProposalUseCase(this._repository);

  Future<ProposalEntity> call({
    required String proposalId,
    required String title,
    required String category,
    required String description,
  }) =>
      _repository.updateProposal(
        proposalId: proposalId,
        title: title,
        category: category,
        description: description,
      );
}
