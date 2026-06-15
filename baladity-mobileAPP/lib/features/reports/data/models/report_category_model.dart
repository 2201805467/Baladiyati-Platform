import '../../domain/entities/report_category_entity.dart';

class ReportCategoryModel extends ReportCategoryEntity {
  const ReportCategoryModel({
    required super.id,
    required super.name,
    super.departmentName,
  });

  factory ReportCategoryModel.fromJson(Map<String, dynamic> json) {
    final department = json['department'];

    return ReportCategoryModel(
      id: (json['id'] as num).toInt(),
      name: json['category_name']?.toString() ?? '',
      departmentName: department is Map
          ? department['dept_name']?.toString()
          : null,
    );
  }
}
