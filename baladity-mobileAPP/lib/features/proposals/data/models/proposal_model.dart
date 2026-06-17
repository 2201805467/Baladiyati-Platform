import '../../domain/entities/proposal_entity.dart';

class ProposalModel extends ProposalEntity {
  const ProposalModel({
    required super.id,
    super.authorId,
    required super.title,
    required super.category,
    required super.author,
    required super.description,
    super.votes = 0,
    super.isVoted = false,
    required super.expiryDate,
  });

  factory ProposalModel.fromJson(Map<String, dynamic> json) {
    final citizen = json['citizen'];
    final userVotes = json['votes'] is List ? json['votes'] as List : const [];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');

    return ProposalModel(
      id: json['id'].toString(),
      authorId: citizen is Map
          ? (citizen['id'] as num?)?.toInt()
          : (json['citizen_id'] as num?)?.toInt(),
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      author: citizen is Map
          ? citizen['full_name']?.toString() ?? 'Unknown'
          : json['author']?.toString() ?? 'Unknown',
      description: json['description']?.toString() ?? '',
      votes:
          (json['support_votes_count'] as num?)?.toInt() ??
          (json['votes'] as num?)?.toInt() ??
          0,
      isVoted: (json['is_voted'] as bool?) ?? userVotes.isNotEmpty,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'].toString())
          : createdAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (authorId != null) 'citizen_id': authorId,
    'title': title,
    'category': category,
    'author': author,
    'description': description,
    'votes': votes,
    'is_voted': isVoted,
    'expiry_date': expiryDate.toIso8601String(),
  };
}
