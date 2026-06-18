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
      id: _intOrZero(json['id']),
      municipalityId: _intOrZero(json['municipality_id']),
      facilityType: json['facility_type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description:
          json['services']?.toString() ??
          (json['description'] as String?) ??
          '',
      latitude: _doubleOrZero(json['latitude']),
      longitude: _doubleOrZero(json['longitude']),
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

  static int _intOrZero(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _doubleOrZero(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
