import 'package:dio/dio.dart';
import '../../../../core/network/api_constants.dart';
import '../models/facility_model.dart';

abstract class FacilitiesRemoteDataSource {
  Future<List<FacilityModel>> getFacilities({
    String? type,
    int? municipalityId,
    int page = 1,
  });
}

class FacilitiesRemoteDataSourceImpl implements FacilitiesRemoteDataSource {
  final Dio _dio;
  FacilitiesRemoteDataSourceImpl(this._dio);

  @override
  Future<List<FacilityModel>> getFacilities({
    String? type,
    int? municipalityId,
    int page = 1,
  }) async {
    final res = await _dio.get(
      ApiConstants.facilities,
      queryParameters: {'facility_type': ?type, 'page': page},
    );
    final List data = (res.data['data'] ?? res.data) as List;
    return data
        .map((e) => FacilityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
