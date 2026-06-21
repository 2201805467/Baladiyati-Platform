import '../../domain/entities/report_category_entity.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/entities/report_image_classification_entity.dart';

class ReportsState {
  final bool isLoading;
  final bool isSubmitting;
  final bool isLoadingDetails;
  final bool isSubmittingComment;
  final bool isSubmittingRating;
  final bool isClassifyingImage;
  final List<ReportEntity> reports;
  final ReportEntity? selectedReport;
  final List<ReportCategoryEntity> categories;
  final ReportImageClassificationEntity? imageClassification;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;

  const ReportsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isLoadingDetails = false,
    this.isSubmittingComment = false,
    this.isSubmittingRating = false,
    this.isClassifyingImage = false,
    this.reports = const [],
    this.selectedReport,
    this.categories = const [],
    this.imageClassification,
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 1,
  });

  ReportsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    bool? isLoadingDetails,
    bool? isSubmittingComment,
    bool? isSubmittingRating,
    bool? isClassifyingImage,
    List<ReportEntity>? reports,
    ReportEntity? selectedReport,
    List<ReportCategoryEntity>? categories,
    ReportImageClassificationEntity? imageClassification,
    bool clearImageClassification = false,
    String? errorMessage,
    bool clearError = false,
    bool? hasMore,
    int? currentPage,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
      isSubmittingComment: isSubmittingComment ?? this.isSubmittingComment,
      isSubmittingRating: isSubmittingRating ?? this.isSubmittingRating,
      isClassifyingImage: isClassifyingImage ?? this.isClassifyingImage,
      reports: reports ?? this.reports,
      selectedReport: selectedReport ?? this.selectedReport,
      categories: categories ?? this.categories,
      imageClassification: clearImageClassification
          ? null
          : (imageClassification ?? this.imageClassification),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}
