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
    super.status,
    super.createdAt,
    super.comments,
    super.ratingStars,
    super.ratingComment,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    final imagesJson = json['images'];
    final firstImage =
        imagesJson is List && imagesJson.isNotEmpty && imagesJson.first is Map
        ? (imagesJson.first as Map)['image_url']?.toString()
        : null;
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
      imageUrl: json['image_url']?.toString() ?? firstImage,
      status: json['status']?.toString() ?? 'قيد الانتظار',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      comments: comments,
      ratingStars: ratingJson is Map ? _intOrNull(ratingJson['stars']) : null,
      ratingComment: ratingJson is Map
          ? ratingJson['comment']?.toString()
          : null,
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
    'status': status,
    if (ratingStars != null) 'rating_stars': ratingStars,
    if (ratingComment != null) 'rating_comment': ratingComment,
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
