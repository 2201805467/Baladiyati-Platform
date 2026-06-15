import '../../domain/entities/facility_entity.dart';

class FacilityModel extends FacilityEntity {
  const FacilityModel({
    required super.id,
    required super.municipalityId,
    required super.facilityType,
    required super.name,
    required super.description,
    required super.latitude,
    required super.longitude,
    required super.address,
    required super.openingHours,
    required super.phone,
    required super.isOpen,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    return FacilityModel(
      id: (json['id'] as num).toInt(),
      municipalityId: (json['municipality_id'] as num?)?.toInt() ?? 0,
      facilityType: json['facility_type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description:
          json['services']?.toString() ??
          (json['description'] as String?) ??
          '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: (json['address'] as String?) ?? '',
      openingHours:
          json['working_hours']?.toString() ??
          (json['opening_hours'] as String?) ??
          '',
      phone: (json['phone'] as String?) ?? '',
      isOpen:
          (json['is_active'] as bool?) ?? (json['is_open'] as bool?) ?? true,
    );
  }
}
