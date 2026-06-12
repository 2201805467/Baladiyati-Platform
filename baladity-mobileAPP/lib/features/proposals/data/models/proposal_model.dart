import '../../domain/entities/proposal_entity.dart';

class ProposalModel extends ProposalEntity {
  const ProposalModel({
    required super.id,
    required super.title,
    required super.category,
    required super.author,
    required super.description,
    super.votes = 0,
    super.isVoted = false,
    required super.expiryDate,
  });

  factory ProposalModel.fromJson(Map<String, dynamic> json) {
    return ProposalModel(
      id: json['id'].toString(),
      title: json['title'] as String,
      category: json['category'] as String,
      author: (json['author'] as String?) ?? 'مجهول',
      description: json['description'] as String,
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      isVoted: (json['is_voted'] as bool?) ?? false,
      expiryDate: DateTime.parse(json['expiry_date'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'author': author,
        'description': description,
        'votes': votes,
        'is_voted': isVoted,
        'expiry_date': expiryDate.toIso8601String(),
      };
}
