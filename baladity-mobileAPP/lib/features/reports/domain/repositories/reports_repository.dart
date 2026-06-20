import '../entities/report_entity.dart';
import '../entities/report_category_entity.dart';
import '../entities/report_comment_entity.dart';
import '../entities/report_image_classification_entity.dart';

abstract class ReportsRepository {
  Future<List<ReportEntity>> getReports({int page = 1});
  Future<ReportEntity> getReport(int reportId);
  Future<List<ReportCategoryEntity>> getCategories();
  Future<ReportImageClassificationEntity> classifyImage({
    required String imagePath,
  });

  Future<ReportEntity> createReport({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? imagePath,
  });
  Future<ReportCommentEntity> addComment({
    required int reportId,
    required String text,
  });
}
