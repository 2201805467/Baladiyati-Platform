import '../entities/facility_entity.dart';
import '../repositories/facilities_repository.dart';

class GetFacilitiesUseCase {
  final FacilitiesRepository _repository;
  GetFacilitiesUseCase(this._repository);

  Future<List<FacilityEntity>> call({
    String? type,
    int? municipalityId,
    int page = 1,
  }) =>
      _repository.getFacilities(
          type: type, municipalityId: municipalityId, page: page);
}
