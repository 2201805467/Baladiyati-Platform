class ProposalEntity {
  final String id;
  final int? authorId;
  final String title;
  final String category;
  final String author;
  final String description;
  final String status;
  final int votes;
  final int opposeVotes;
  final bool isVoted;
  final String? myVoteType;
  final DateTime expiryDate;

  const ProposalEntity({
    required this.id,
    this.authorId,
    required this.title,
    required this.category,
    required this.author,
    required this.description,
    this.status = 'accepted',
    this.votes = 0,
    this.opposeVotes = 0,
    this.isVoted = false,
    this.myVoteType,
    required this.expiryDate,
  });

  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool get isAccepted => status == 'accepted';
  bool get isUnderReview => status == 'under_review';

  bool get isSupported => myVoteType == 'support';
  bool get isOpposed => myVoteType == 'oppose';

  ProposalEntity copyWith({
    int? votes,
    int? opposeVotes,
    bool? isVoted,
    String? myVoteType,
    bool clearMyVoteType = false,
  }) {
    return ProposalEntity(
      id: id,
      authorId: authorId,
      title: title,
      category: category,
      author: author,
      description: description,
      status: status,
      votes: votes ?? this.votes,
      opposeVotes: opposeVotes ?? this.opposeVotes,
      isVoted: isVoted ?? this.isVoted,
      myVoteType: clearMyVoteType ? null : (myVoteType ?? this.myVoteType),
      expiryDate: expiryDate,
    );
  }
}
