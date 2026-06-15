import '../../domain/entities/report_category_entity.dart';
import '../../domain/entities/report_entity.dart';

class ReportsState {
  final bool isLoading;
  final bool isSubmitting;
  final List<ReportEntity> reports;
  final List<ReportCategoryEntity> categories;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;

  const ReportsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.reports = const [],
    this.categories = const [],
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 1,
  });

  ReportsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<ReportEntity>? reports,
    List<ReportCategoryEntity>? categories,
    String? errorMessage,
    bool clearError = false,
    bool? hasMore,
    int? currentPage,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      reports: reports ?? this.reports,
      categories: categories ?? this.categories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}
