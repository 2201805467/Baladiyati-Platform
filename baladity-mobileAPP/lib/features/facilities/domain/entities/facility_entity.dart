class FacilityEntity {
  final int id;
  final int municipalityId;
  final String facilityType;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String address;
  final String openingHours;
  final String phone;
  final bool isOpen;

  const FacilityEntity({
    required this.id,
    required this.municipalityId,
    required this.facilityType,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.openingHours,
    required this.phone,
    required this.isOpen,
  });
}
