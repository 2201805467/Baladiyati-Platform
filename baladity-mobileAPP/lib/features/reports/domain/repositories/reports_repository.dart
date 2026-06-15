import '../entities/report_entity.dart';
import '../entities/report_category_entity.dart';

abstract class ReportsRepository {
  Future<List<ReportEntity>> getReports({int page = 1});
  Future<List<ReportCategoryEntity>> getCategories();

  Future<ReportEntity> createReport({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? imagePath,
  });
}
