import '../../domain/entities/proposal_entity.dart';
import '../../domain/repositories/proposals_repository.dart';
import '../datasources/proposals_remote_datasource.dart';

class ProposalsRepositoryImpl implements ProposalsRepository {
  final ProposalsRemoteDataSource _dataSource;
  ProposalsRepositoryImpl(this._dataSource);

  @override
  Future<List<ProposalEntity>> getProposals({int page = 1, bool mine = false}) =>
      _dataSource.getProposals(page: page, mine: mine);

  @override
  Future<ProposalEntity> vote(String proposalId, {required String voteType}) =>
      _dataSource.vote(proposalId, voteType: voteType);

  @override
  Future<ProposalEntity> unvote(String proposalId) =>
      _dataSource.unvote(proposalId);

  @override
  Future<void> suggestProposal({
    required String title,
    required String category,
    required String description,
  }) => _dataSource.suggestProposal(
        title: title,
        category: category,
        description: description,
      );

  @override
  Future<ProposalEntity> updateProposal({
    required String proposalId,
    required String title,
    required String category,
    required String description,
  }) => _dataSource.updateProposal(
        proposalId: proposalId,
        title: title,
        category: category,
        description: description,
      );

  @override
  Future<void> deleteProposal(String proposalId) =>
      _dataSource.deleteProposal(proposalId);
}
