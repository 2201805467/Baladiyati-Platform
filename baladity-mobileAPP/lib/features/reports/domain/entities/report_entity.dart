import 'report_comment_entity.dart';

class ReportEntity {
  final int? id;
  final String category;
  final String description;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final String? imageUrl;
  final String status;
  final DateTime? createdAt;
  final List<ReportCommentEntity> comments;

  const ReportEntity({
    this.id,
    required this.category,
    required this.description,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.imageUrl,
    this.status = 'قيد الانتظار',
    this.createdAt,
    this.comments = const [],
  });
}
