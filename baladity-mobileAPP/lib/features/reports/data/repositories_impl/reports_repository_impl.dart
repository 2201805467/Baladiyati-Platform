import '../../domain/entities/report_entity.dart';
import '../../domain/entities/report_category_entity.dart';
import '../../domain/entities/report_comment_entity.dart';
import '../../domain/entities/report_image_classification_entity.dart';
import '../../domain/repositories/reports_repository.dart';
import '../datasources/reports_remote_datasource.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl(this._dataSource);
  final ReportsRemoteDataSource _dataSource;

  @override
  Future<List<ReportEntity>> getReports({int page = 1}) =>
      _dataSource.getReports(page: page);

  @override
  Future<ReportEntity> getReport(int reportId) =>
      _dataSource.getReport(reportId);

  @override
  Future<List<ReportCategoryEntity>> getCategories() =>
      _dataSource.getCategories();

  @override
  Future<ReportImageClassificationEntity> classifyImage({
    required String imagePath,
  }) => _dataSource.classifyImage(imagePath: imagePath);

  @override
  Future<ReportEntity> createReport({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? imagePath,
  }) => _dataSource.createReport(
    category: category,
    description: description,
    latitude: latitude,
    longitude: longitude,
    locationAddress: locationAddress,
    imagePath: imagePath,
  );

  @override
  Future<ReportCommentEntity> addComment({
    required int reportId,
    required String text,
  }) => _dataSource.addComment(reportId: reportId, text: text);
}
