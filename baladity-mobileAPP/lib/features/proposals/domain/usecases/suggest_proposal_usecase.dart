import '../repositories/proposals_repository.dart';

class SuggestProposalUseCase {
  final ProposalsRepository _repository;
  SuggestProposalUseCase(this._repository);

  Future<void> call({
    required String title,
    required String category,
    required String description,
  }) =>
      _repository.suggestProposal(
        title: title,
        category: category,
        description: description,
      );
}
