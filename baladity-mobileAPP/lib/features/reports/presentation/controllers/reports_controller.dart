import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/reports_remote_datasource.dart';
import '../../data/repositories_impl/reports_repository_impl.dart';
import '../../domain/repositories/reports_repository.dart';
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

final getReportsUseCaseProvider =
    Provider((ref) => GetReportsUseCase(ref.read(reportsRepositoryProvider)));

final createReportUseCaseProvider =
    Provider((ref) => CreateReportUseCase(ref.read(reportsRepositoryProvider)));

// ─── Reports Controller ───────────────────────────────────────────────────────

final reportsControllerProvider =
    StateNotifierProvider<ReportsController, ReportsState>(
  (ref) => ReportsController(
    ref.read(getReportsUseCaseProvider),
    ref.read(createReportUseCaseProvider),
  ),
);

class ReportsController extends StateNotifier<ReportsState> {
  ReportsController(this._getReports, this._createReport)
      : super(const ReportsState());

  final GetReportsUseCase _getReports;
  final CreateReportUseCase _createReport;

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
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}
