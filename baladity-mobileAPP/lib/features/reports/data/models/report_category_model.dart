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
      id: _intOrZero(json['id']),
      name: json['category_name']?.toString() ?? '',
      departmentName: department is Map
          ? department['dept_name']?.toString()
          : null,
    );
  }

  static int _intOrZero(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
