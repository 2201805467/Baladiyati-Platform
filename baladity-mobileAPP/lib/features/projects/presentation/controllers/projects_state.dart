import '../../domain/entities/project_entity.dart';

class ProjectsState {
  final bool isLoading;
  final List<ProjectEntity> projects;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;

  const ProjectsState({
    this.isLoading = false,
    this.projects = const [],
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 1,
  });

  ProjectsState copyWith({
    bool? isLoading,
    List<ProjectEntity>? projects,
    String? errorMessage,
    bool clearError = false,
    bool? hasMore,
    int? currentPage,
  }) {
    return ProjectsState(
      isLoading: isLoading ?? this.isLoading,
      projects: projects ?? this.projects,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}
