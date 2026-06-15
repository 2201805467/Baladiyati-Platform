class ReportCategoryEntity {
  final int id;
  final String name;
  final String? departmentName;

  const ReportCategoryEntity({
    required this.id,
    required this.name,
    this.departmentName,
  });
}
