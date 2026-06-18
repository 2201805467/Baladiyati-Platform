import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/reports_remote_datasource.dart';
import '../../data/repositories_impl/reports_repository_impl.dart';
import '../../domain/repositories/reports_repository.dart';
import '../../domain/entities/report_image_classification_entity.dart';
import '../../domain/usecases/create_report_usecase.dart';
import '../../domain/usecases/get_reports_usecase.dart';
import 'reports_state.dart';

// ─── Dependency Providers ─────────────────────────────────────────────────────

final reportsRemoteDataSourceProvider = Provider<ReportsRemoteDataSource>(
  (ref) => ReportsRemoteDataSourceImpl(ref.read(dioProvider)),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepositoryImpl(ref.read(reportsRemoteDataSourceProvider)),
);

final getReportsUseCaseProvider = Provider(
  (ref) => GetReportsUseCase(ref.read(reportsRepositoryProvider)),
);

final createReportUseCaseProvider = Provider(
  (ref) => CreateReportUseCase(ref.read(reportsRepositoryProvider)),
);

// ─── Reports Controller ───────────────────────────────────────────────────────

final reportsControllerProvider =
    NotifierProvider<ReportsController, ReportsState>(
      () => ReportsController(),
    );

class ReportsController extends Notifier<ReportsState> {
  late GetReportsUseCase _getReports;
  late CreateReportUseCase _createReport;
  late ReportsRepository _repository;

  @override
  ReportsState build() {
    _getReports = ref.read(getReportsUseCaseProvider);
    _createReport = ref.read(createReportUseCaseProvider);
    _repository = ref.read(reportsRepositoryProvider);
    return const ReportsState();
  }

  Future<void> fetchReports({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.currentPage;
    if (!refresh && !state.hasMore) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await _getReports(page: page);
      final updated = refresh ? results : [...state.reports, ...results];
      state = state.copyWith(
        isLoading: false,
        reports: updated,
        hasMore: results.isNotEmpty,
        currentPage: page + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchCategories() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final categories = await _repository.getCategories();
      state = state.copyWith(isLoading: false, categories: categories);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearImageClassification() {
    state = state.copyWith(
      isClassifyingImage: false,
      clearImageClassification: true,
    );
  }

  Future<ReportImageClassificationEntity?> classifyImage({
    required String imagePath,
  }) async {
    state = state.copyWith(
      isClassifyingImage: true,
      clearError: true,
      clearImageClassification: true,
    );
    try {
      final classification = await _repository.classifyImage(
        imagePath: imagePath,
      );
      state = state.copyWith(
        isClassifyingImage: false,
        imageClassification: classification,
      );
      return classification;
    } catch (e) {
      state = state.copyWith(
        isClassifyingImage: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<bool> submitReport({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? imagePath,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final report = await _createReport(
        category: category,
        description: description,
        latitude: latitude,
        longitude: longitude,
        locationAddress: locationAddress,
        imagePath: imagePath,
      );
      state = state.copyWith(
        isSubmitting: false,
        reports: [report, ...state.reports],
        clearImageClassification: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}
