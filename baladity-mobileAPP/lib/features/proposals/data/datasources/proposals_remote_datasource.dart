import 'package:dio/dio.dart';
import '../../../../core/network/api_constants.dart';
import '../models/proposal_model.dart';

abstract class ProposalsRemoteDataSource {
  Future<List<ProposalModel>> getProposals({int page = 1});
  Future<ProposalModel> vote(String proposalId);
  Future<ProposalModel> unvote(String proposalId);
  Future<void> suggestProposal({
    required String title,
    required String category,
    required String description,
  });
}

class ProposalsRemoteDataSourceImpl implements ProposalsRemoteDataSource {
  final Dio _dio;
  ProposalsRemoteDataSourceImpl(this._dio);

  @override
  Future<List<ProposalModel>> getProposals({int page = 1}) async {
    final res = await _dio.get(
      ApiConstants.proposals,
      queryParameters: {'page': page},
    );
    final List data = res.data['data'] as List;
    return data.map((e) => ProposalModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ProposalModel> vote(String proposalId) async {
    final endpoint = ApiConstants.proposalVote.replaceFirst('{id}', proposalId);
    final res = await _dio.post(endpoint);
    return ProposalModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<ProposalModel> unvote(String proposalId) async {
    final endpoint = ApiConstants.proposalVote.replaceFirst('{id}', proposalId);
    final res = await _dio.delete(endpoint);
    return ProposalModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> suggestProposal({
    required String title,
    required String category,
    required String description,
  }) async {
    await _dio.post(
      ApiConstants.suggestService,
      data: {
        'title': title,
        'category': category,
        'description': description,
      },
    );
  }
}
