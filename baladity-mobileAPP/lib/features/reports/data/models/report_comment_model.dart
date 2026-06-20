import '../../domain/entities/report_comment_entity.dart';

class ReportCommentModel extends ReportCommentEntity {
  const ReportCommentModel({
    super.id,
    required super.text,
    required super.authorName,
    required super.authorRole,
    super.createdAt,
  });

  factory ReportCommentModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final role = user is Map ? user['role'] : null;

    return ReportCommentModel(
      id: _intOrNull(json['id']),
      text: json['comment_text']?.toString() ?? '',
      authorName: user is Map
          ? user['full_name']?.toString() ??
                user['name']?.toString() ??
                'مستخدم'
          : 'مستخدم',
      authorRole: role is Map
          ? _roleLabel(role['role_name']?.toString())
          : _roleLabel(user is Map ? user['role']?.toString() : null),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  static String _roleLabel(String? role) {
    return switch (role) {
      'citizen' => 'مواطن',
      'reception' => 'موظف استقبال',
      'department_officer' => 'موظف القسم',
      'admin' => 'أدمن',
      _ => 'مستخدم',
    };
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
