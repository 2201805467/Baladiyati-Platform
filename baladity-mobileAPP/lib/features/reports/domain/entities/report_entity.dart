import 'report_comment_entity.dart';

class ReportEntity {
  final int? id;
  final String category;
  final String description;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final String? imageUrl;
  final String? completionImageUrl;
  final String? completionReport;
  final String status;
  final DateTime? createdAt;
  final List<ReportCommentEntity> comments;
  final int? ratingStars;
  final String? ratingComment;
  final int upvotesCount;
  final int downvotesCount;
  final String? viewerVote;
  final double? distanceKm;

  const ReportEntity({
    this.id,
    required this.category,
    required this.description,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.imageUrl,
    this.completionImageUrl,
    this.completionReport,
    this.status = 'قيد الانتظار',
    this.createdAt,
    this.comments = const [],
    this.ratingStars,
    this.ratingComment,
    this.upvotesCount = 0,
    this.downvotesCount = 0,
    this.viewerVote,
    this.distanceKm,
  });
}
