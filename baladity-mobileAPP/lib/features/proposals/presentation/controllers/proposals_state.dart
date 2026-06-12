import '../../domain/entities/proposal_entity.dart';

class ProposalsState {
  final bool isLoading;
  final bool isSubmitting;
  final List<ProposalEntity> proposals;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;

  const ProposalsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.proposals = const [],
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 1,
  });

  ProposalsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<ProposalEntity>? proposals,
    String? errorMessage,
    bool clearError = false,
    bool? hasMore,
    int? currentPage,
  }) {
    return ProposalsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      proposals: proposals ?? this.proposals,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}
