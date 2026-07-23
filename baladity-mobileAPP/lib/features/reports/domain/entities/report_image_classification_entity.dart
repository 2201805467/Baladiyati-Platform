class ReportImageClassificationEntity {
  final int? categoryId;
  final String? categoryName;
  final String? departmentName;
  final int confidence;
  final bool needsManualReview;
  final String provider;
  final String? reasoning;
  final String? suggestedDescription;
  final String? providerFailureReason;

  const ReportImageClassificationEntity({
    required this.categoryId,
    required this.categoryName,
    required this.departmentName,
    required this.confidence,
    required this.needsManualReview,
    required this.provider,
    this.reasoning,
    this.suggestedDescription,
    this.providerFailureReason,
  });

  bool get hasConfidentCategory =>
      categoryId != null && !needsManualReview && confidence >= 50;
}
