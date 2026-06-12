import '../entities/report_entity.dart';
import '../repositories/reports_repository.dart';

class CreateReportUseCase {
  final ReportsRepository _repository;
  CreateReportUseCase(this._repository);

  Future<ReportEntity> call({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? imagePath,
  }) =>
      _repository.createReport(
        category: category,
        description: description,
        latitude: latitude,
        longitude: longitude,
        locationAddress: locationAddress,
        imagePath: imagePath,
      );
}
