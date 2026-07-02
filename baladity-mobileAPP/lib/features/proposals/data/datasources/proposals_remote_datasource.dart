import 'package:dio/dio.dart';
import '../../../../core/network/api_constants.dart';
import '../models/proposal_model.dart';

abstract class ProposalsRemoteDataSource {
  Future<List<ProposalModel>> getProposals({int page = 1, bool mine = false});
  Future<ProposalModel> vote(String proposalId, {required String voteType});
  Future<ProposalModel> unvote(String proposalId);
  Future<void> suggestProposal({
    required String title,
    required String category,
    required String description,
  });
  Future<ProposalModel> updateProposal({
    required String proposalId,
    required String title,
    required String category,
    required String description,
  });
  Future<void> deleteProposal(String proposalId);
}

class ProposalsRemoteDataSourceImpl implements ProposalsRemoteDataSource {
  final Dio _dio;
  ProposalsRemoteDataSourceImpl(this._dio);

  @override
  Future<List<ProposalModel>> getProposals({
    int page = 1,
    bool mine = false,
  }) async {
    final res = await _dio.get(
      ApiConstants.proposals,
      queryParameters: {'page': page, if (mine) 'mine': true},
    );
    final List data = (res.data['data'] ?? res.data) as List;
    return data
        .map((e) => ProposalModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProposalModel> vote(
    String proposalId, {
    required String voteType,
  }) async {
    final endpoint = ApiConstants.proposalVote.replaceFirst('{id}', proposalId);
    await _dio.post(endpoint, data: {'vote_type': voteType});
    return _placeholder(proposalId);
  }

  @override
  Future<ProposalModel> unvote(String proposalId) async {
    final endpoint = ApiConstants.proposalVote.replaceFirst('{id}', proposalId);
    await _dio.delete(endpoint);
    return _placeholder(proposalId);
  }

  @override
  Future<void> suggestProposal({
    required String title,
    required String category,
    required String description,
  }) async {
    await _dio.post(
      ApiConstants.suggestService,
      data: {'title': title, 'category': category, 'description': description},
    );
  }

  @override
  Future<ProposalModel> updateProposal({
    required String proposalId,
    required String title,
    required String category,
    required String description,
  }) async {
    final res = await _dio.put(
      '${ApiConstants.proposals}/$proposalId',
      data: {'title': title, 'category': category, 'description': description},
    );
    final data = (res.data['suggestion'] ?? res.data) as Map<String, dynamic>;
    return ProposalModel.fromJson(data);
  }

  @override
  Future<void> deleteProposal(String proposalId) async {
    await _dio.delete('${ApiConstants.proposals}/$proposalId');
  }

  ProposalModel _placeholder(String proposalId) => ProposalModel(
    id: proposalId,
    title: '',
    category: '',
    author: '',
    description: '',
    expiryDate: DateTime.now(),
  );
}
