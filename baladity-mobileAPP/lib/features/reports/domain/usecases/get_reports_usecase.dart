import '../entities/report_entity.dart';
import '../repositories/reports_repository.dart';

class GetReportsUseCase {
  final ReportsRepository _repository;
  GetReportsUseCase(this._repository);

  Future<List<ReportEntity>> call({int page = 1}) =>
      _repository.getReports(page: page);
}
