import '../../domain/entities/project_entity.dart';

class ProjectModel extends ProjectEntity {
  const ProjectModel({
    super.id,
    required super.municipalityId,
    required super.name,
    required super.description,
    required super.status,
    required super.startDate,
    super.endDate,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] != null ? (json['id'] as num).toInt() : null,
      municipalityId: (json['municipality_id'] as num).toInt(),
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'قيد التنفيذ',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
    );
  }
}
