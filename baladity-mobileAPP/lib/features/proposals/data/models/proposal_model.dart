import '../../domain/entities/proposal_entity.dart';

class ProposalModel extends ProposalEntity {
  const ProposalModel({
    required super.id,
    super.authorId,
    required super.title,
    required super.category,
    required super.author,
    required super.description,
    super.status = 'accepted',
    super.votes = 0,
    super.opposeVotes = 0,
    super.isVoted = false,
    super.myVoteType,
    required super.expiryDate,
  });

  factory ProposalModel.fromJson(Map<String, dynamic> json) {
    final citizen = json['citizen'];
    final userVotes = json['votes'] is List ? json['votes'] as List : const [];
    final myVoteType = userVotes.isNotEmpty && userVotes.first is Map
        ? (userVotes.first as Map)['vote_type']?.toString()
        : json['my_vote_type']?.toString();
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final fallbackExpiry =
        createdAt?.add(const Duration(days: 30)) ??
        DateTime.now().add(const Duration(days: 30));

    return ProposalModel(
      id: json['id'].toString(),
      authorId: citizen is Map
          ? _intOrNull(citizen['id'])
          : _intOrNull(json['citizen_id']),
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      author: citizen is Map
          ? citizen['full_name']?.toString() ?? 'Unknown'
          : json['author']?.toString() ?? 'Unknown',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'accepted',
      votes:
          _intOrNull(json['support_votes_count']) ??
          _intOrNull(json['votes']) ??
          0,
      opposeVotes: _intOrNull(json['oppose_votes_count']) ?? 0,
      isVoted: (json['is_voted'] as bool?) ?? myVoteType != null,
      myVoteType: myVoteType,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'].toString())
          : fallbackExpiry,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (authorId != null) 'citizen_id': authorId,
    'title': title,
    'category': category,
    'author': author,
    'description': description,
    'status': status,
    'votes': votes,
    'oppose_votes_count': opposeVotes,
    'is_voted': isVoted,
    if (myVoteType != null) 'my_vote_type': myVoteType,
    'expiry_date': expiryDate.toIso8601String(),
  };

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
