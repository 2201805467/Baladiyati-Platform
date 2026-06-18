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
      id: _intOrNull(json['id']),
      municipalityId: _intOrNull(json['municipality_id']) ?? 0,
      name: json['name']?.toString() ?? '',
      description: (json['description'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'قيد التنفيذ',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
    );
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
