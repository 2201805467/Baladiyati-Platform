import '../entities/project_entity.dart';
import '../repositories/projects_repository.dart';

class GetProjectsUseCase {
  final ProjectsRepository _repository;
  GetProjectsUseCase(this._repository);

  Future<List<ProjectEntity>> call({int? municipalityId, int page = 1}) =>
      _repository.getProjects(municipalityId: municipalityId, page: page);
}
