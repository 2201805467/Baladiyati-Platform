import '../../domain/entities/facility_entity.dart';
import '../../domain/repositories/facilities_repository.dart';
import '../datasources/facilities_remote_datasource.dart';

class FacilitiesRepositoryImpl implements FacilitiesRepository {
  final FacilitiesRemoteDataSource _dataSource;
  FacilitiesRepositoryImpl(this._dataSource);

  @override
  Future<List<FacilityEntity>> getFacilities({
    String? type,
    int? municipalityId,
    int page = 1,
  }) =>
      _dataSource.getFacilities(
          type: type, municipalityId: municipalityId, page: page);
}
