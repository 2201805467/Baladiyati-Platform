import '../../domain/entities/report_image_classification_entity.dart';

class ReportImageClassificationModel extends ReportImageClassificationEntity {
  const ReportImageClassificationModel({
    required super.categoryId,
    required super.categoryName,
    required super.departmentName,
    required super.confidence,
    required super.needsManualReview,
    required super.provider,
    super.reasoning,
  });

  factory ReportImageClassificationModel.fromJson(Map<String, dynamic> json) {
    final classification = (json['classification'] ?? json) as Map;
    final category = classification['suggested_category'];
    final department = category is Map ? category['department'] : null;

    return ReportImageClassificationModel(
      categoryId: category is Map ? (category['id'] as num?)?.toInt() : null,
      categoryName: category is Map
          ? category['category_name']?.toString() ??
                category['name']?.toString()
          : null,
      departmentName: department is Map
          ? department['dept_name']?.toString() ??
                department['name']?.toString()
          : null,
      confidence: (classification['confidence'] as num?)?.toInt() ?? 0,
      needsManualReview: classification['needs_manual_review'] == true,
      provider: classification['provider']?.toString() ?? 'unknown',
      reasoning: classification['reasoning']?.toString(),
    );
  }
}
