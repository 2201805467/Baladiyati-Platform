class ReportCommentEntity {
  final int? id;
  final String text;
  final String authorName;
  final String authorRole;
  final DateTime? createdAt;

  const ReportCommentEntity({
    this.id,
    required this.text,
    required this.authorName,
    required this.authorRole,
    this.createdAt,
  });
}
