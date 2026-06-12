import '../entities/facility_entity.dart';

abstract class FacilitiesRepository {
  Future<List<FacilityEntity>> getFacilities({
    String? type,
    int? municipalityId,
    int page = 1,
  });
}
