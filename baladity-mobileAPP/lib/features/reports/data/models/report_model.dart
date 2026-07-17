import '../../domain/entities/report_entity.dart';
import 'report_comment_model.dart';

class ReportModel extends ReportEntity {
  const ReportModel({
    super.id,
    required super.category,
    required super.description,
    super.latitude,
    super.longitude,
    super.locationAddress,
    super.imageUrl,
    super.completionImageUrl,
    super.completionReport,
    super.status,
    super.createdAt,
    super.comments,
    super.ratingStars,
    super.ratingComment,
    super.upvotesCount,
    super.downvotesCount,
    super.viewerVote,
    super.distanceKm,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    final imagesJson = json['images'];
    final beforeImage = _imageUrlByType(imagesJson, 'before');
    final afterImage = _imageUrlByType(imagesJson, 'after');
    final firstImage = _firstImageUrl(imagesJson);
    final comments = _commentsFromJson(json['comments']);
    final ratingJson = json['rating'];

    return ReportModel(
      id: _intOrNull(json['id']),
      category: categoryJson is Map
          ? categoryJson['category_name']?.toString() ?? ''
          : json['category']?.toString() ?? '',
      description:
          json['description']?.toString() ?? json['title']?.toString() ?? '',
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      locationAddress: json['location_address']?.toString(),
      imageUrl: json['image_url']?.toString() ?? beforeImage ?? firstImage,
      completionImageUrl:
          json['completion_image_url']?.toString() ?? afterImage,
      completionReport: json['completion_report']?.toString(),
      status: json['status']?.toString() ?? 'قيد الانتظار',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      comments: comments,
      ratingStars: ratingJson is Map ? _intOrNull(ratingJson['stars']) : null,
      ratingComment: ratingJson is Map
          ? ratingJson['comment']?.toString()
          : null,
      upvotesCount: _intOrNull(json['upvotes_count']) ?? 0,
      downvotesCount: _intOrNull(json['downvotes_count']) ?? 0,
      viewerVote: json['viewer_vote']?.toString(),
      distanceKm: _doubleOrNull(json['distance_km']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'category': category,
    'description': description,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (locationAddress != null) 'location_address': locationAddress,
    if (imageUrl != null) 'image_url': imageUrl,
    if (completionImageUrl != null) 'completion_image_url': completionImageUrl,
    if (completionReport != null) 'completion_report': completionReport,
    'status': status,
    if (ratingStars != null) 'rating_stars': ratingStars,
    if (ratingComment != null) 'rating_comment': ratingComment,
    'upvotes_count': upvotesCount,
    'downvotes_count': downvotesCount,
    if (viewerVote != null) 'viewer_vote': viewerVote,
    if (distanceKm != null) 'distance_km': distanceKm,
  };

  static List<ReportCommentModel> _commentsFromJson(dynamic value) {
    if (value is! List) return const [];

    final comments = value
        .whereType<Map>()
        .map((e) => ReportCommentModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    comments.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return -1;
      if (bDate == null) return 1;
      return aDate.compareTo(bDate);
    });

    return comments;
  }

  static String? _firstImageUrl(dynamic value) {
    if (value is! List || value.isEmpty) return null;

    for (final image in value.whereType<Map>()) {
      final url = image['image_url']?.toString();
      if (url != null && url.isNotEmpty) return url;
    }

    return null;
  }

  static String? _imageUrlByType(dynamic value, String type) {
    if (value is! List) return null;

    for (final image in value.whereType<Map>()) {
      if (image['image_type']?.toString() == type) {
        final url = image['image_url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
    }

    return null;
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _doubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
