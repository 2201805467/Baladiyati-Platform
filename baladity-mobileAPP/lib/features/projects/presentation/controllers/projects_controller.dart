import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/projects_remote_datasource.dart';
import '../../data/repositories_impl/projects_repository_impl.dart';
import '../../domain/repositories/projects_repository.dart';
import '../../domain/usecases/get_projects_usecase.dart';
import 'projects_state.dart';

final projectsRemoteDataSourceProvider = Provider<ProjectsRemoteDataSource>(
  (ref) => ProjectsRemoteDataSourceImpl(ref.read(dioProvider)),
);

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ProjectsRepositoryImpl(ref.read(projectsRemoteDataSourceProvider)),
);

final getProjectsUseCaseProvider = Provider<GetProjectsUseCase>(
  (ref) => GetProjectsUseCase(ref.read(projectsRepositoryProvider)),
);

final projectsControllerProvider =
    StateNotifierProvider<ProjectsController, ProjectsState>(
  (ref) => ProjectsController(ref.read(getProjectsUseCaseProvider)),
);

class ProjectsController extends StateNotifier<ProjectsState> {
  final GetProjectsUseCase _getProjects;

  ProjectsController(this._getProjects) : super(const ProjectsState());

  Future<void> fetchProjects({
    int? municipalityId,
    bool refresh = false,
  }) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.currentPage;
    if (!refresh && !state.hasMore) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await _getProjects(
        municipalityId: municipalityId,
        page: page,
      );

      final updated = refresh ? results : [...state.projects, ...results];
      state = state.copyWith(
        isLoading: false,
        projects: updated,
        hasMore: results.isNotEmpty,
        currentPage: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}
