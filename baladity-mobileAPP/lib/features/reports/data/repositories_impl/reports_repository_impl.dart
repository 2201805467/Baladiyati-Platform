import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/reports_repository.dart';
import '../datasources/reports_remote_datasource.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl(this._dataSource);
  final ReportsRemoteDataSource _dataSource;

  @override
  Future<List<ReportEntity>> getReports({int page = 1}) =>
      _dataSource.getReports(page: page);

  @override
  Future<ReportEntity> createReport({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? imagePath,
  }) =>
      _dataSource.createReport(
        category: category,
        description: description,
        latitude: latitude,
        longitude: longitude,
        locationAddress: locationAddress,
        imagePath: imagePath,
      );
}
