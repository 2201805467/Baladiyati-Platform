import 'package:dio/dio.dart';
import '../../../../core/network/api_constants.dart';
import '../models/project_model.dart';

abstract class ProjectsRemoteDataSource {
  Future<List<ProjectModel>> getProjects({int? municipalityId, int page = 1});
}

class ProjectsRemoteDataSourceImpl implements ProjectsRemoteDataSource {
  final Dio _dio;
  ProjectsRemoteDataSourceImpl(this._dio);

  @override
  Future<List<ProjectModel>> getProjects({
    int? municipalityId,
    int page = 1,
  }) async {
    final res = await _dio.get(
      ApiConstants.projects,
      queryParameters: {
        'municipality_id': ?municipalityId,
        'page': page,
      },
    );
    final List data = res.data['data'] as List;
    return data
        .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
