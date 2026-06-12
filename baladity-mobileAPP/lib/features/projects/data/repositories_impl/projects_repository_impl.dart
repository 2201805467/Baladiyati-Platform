import '../../domain/entities/project_entity.dart';
import '../../domain/repositories/projects_repository.dart';
import '../datasources/projects_remote_datasource.dart';

class ProjectsRepositoryImpl implements ProjectsRepository {
  final ProjectsRemoteDataSource _dataSource;
  ProjectsRepositoryImpl(this._dataSource);

  @override
  Future<List<ProjectEntity>> getProjects({
    int? municipalityId,
    int page = 1,
  }) =>
      _dataSource.getProjects(municipalityId: municipalityId, page: page);
}
