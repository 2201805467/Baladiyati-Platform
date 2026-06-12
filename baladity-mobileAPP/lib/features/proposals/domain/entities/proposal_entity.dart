class ProposalEntity {
  final String id;
  final String title;
  final String category;
  final String author;
  final String description;
  final int votes;
  final bool isVoted;
  final DateTime expiryDate;

  const ProposalEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.author,
    required this.description,
    this.votes = 0,
    this.isVoted = false,
    required this.expiryDate,
  });

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  ProposalEntity copyWith({int? votes, bool? isVoted}) {
    return ProposalEntity(
      id: id,
      title: title,
      category: category,
      author: author,
      description: description,
      votes: votes ?? this.votes,
      isVoted: isVoted ?? this.isVoted,
      expiryDate: expiryDate,
    );
  }
}
