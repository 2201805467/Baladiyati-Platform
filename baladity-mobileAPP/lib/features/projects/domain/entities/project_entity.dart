class ProjectEntity {
  final int? id;
  final int municipalityId;
  final String name;
  final String description;
  final String status;
  final DateTime startDate;
  final DateTime? endDate;

  const ProjectEntity({
    this.id,
    required this.municipalityId,
    required this.name,
    required this.description,
    required this.status,
    required this.startDate,
    this.endDate,
  });
}
