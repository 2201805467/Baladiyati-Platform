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
    super.suggestedDescription,
    super.providerFailureReason,
  });

  factory ReportImageClassificationModel.fromJson(Map<String, dynamic> json) {
    final root = json['data'] is Map ? json['data'] as Map : json;
    final classification = (root['classification'] ?? root) as Map;
    final category =
        classification['suggested_category'] ??
        classification['category'] ??
        classification['suggestedCategory'];
    final department = category is Map ? category['department'] : null;
    final categoryId = category is Map
        ? _intOrNull(category['id'] ?? category['category_id'])
        : _intOrNull(
            classification['category_id'] ??
                classification['categoryId'] ??
                classification['suggested_category_id'],
          );

    return ReportImageClassificationModel(
      categoryId: categoryId,
      categoryName: category is Map
          ? category['category_name']?.toString() ??
                category['name']?.toString()
          : classification['category_name']?.toString() ??
                classification['categoryName']?.toString(),
      departmentName: department is Map
          ? department['dept_name']?.toString() ??
                department['name']?.toString()
          : null,
      confidence: _intOrNull(classification['confidence']) ?? 0,
      needsManualReview: _boolOrFalse(
        classification['needs_manual_review'] ??
            classification['needsManualReview'],
      ),
      provider: classification['provider']?.toString() ?? 'unknown',
      reasoning: classification['reasoning']?.toString(),
      suggestedDescription:
          classification['suggested_description']?.toString() ??
          classification['suggestedDescription']?.toString(),
      providerFailureReason:
          classification['provider_failure_reason']?.toString() ??
          classification['gemini_failure_reason']?.toString() ??
          classification['groq_failure_reason']?.toString(),
    );
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final match = RegExp(r'\d+').firstMatch(value.toString());
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static bool _boolOrFalse(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().toLowerCase().trim();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}
