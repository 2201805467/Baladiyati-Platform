import '../entities/proposal_entity.dart';
import '../repositories/proposals_repository.dart';

class GetProposalsUseCase {
  final ProposalsRepository _repository;
  GetProposalsUseCase(this._repository);

  Future<List<ProposalEntity>> call({int page = 1, bool mine = false}) =>
      _repository.getProposals(page: page, mine: mine);
}
