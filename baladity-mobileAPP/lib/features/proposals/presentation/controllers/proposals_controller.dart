import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/proposals_remote_datasource.dart';
import '../../data/repositories_impl/proposals_repository_impl.dart';
import '../../domain/repositories/proposals_repository.dart';
import '../../domain/usecases/get_proposals_usecase.dart';
import '../../domain/usecases/suggest_proposal_usecase.dart';
import '../../domain/usecases/vote_proposal_usecase.dart';
import 'proposals_state.dart';

// ─── Dependency Providers ─────────────────────────────────────────────────────

final proposalsRemoteDataSourceProvider = Provider<ProposalsRemoteDataSource>(
  (ref) => ProposalsRemoteDataSourceImpl(ref.read(dioProvider)),
);

final proposalsRepositoryProvider = Provider<ProposalsRepository>(
  (ref) => ProposalsRepositoryImpl(
    ref.read(proposalsRemoteDataSourceProvider),
  ),
);

final getProposalsUseCaseProvider = Provider(
  (ref) => GetProposalsUseCase(ref.read(proposalsRepositoryProvider)),
);

final voteProposalUseCaseProvider = Provider(
  (ref) => VoteProposalUseCase(ref.read(proposalsRepositoryProvider)),
);

final suggestProposalUseCaseProvider = Provider(
  (ref) => SuggestProposalUseCase(ref.read(proposalsRepositoryProvider)),
);

// ─── Proposals Controller ─────────────────────────────────────────────────────

final proposalsControllerProvider =
    StateNotifierProvider<ProposalsController, ProposalsState>(
  (ref) => ProposalsController(
    ref.read(getProposalsUseCaseProvider),
    ref.read(voteProposalUseCaseProvider),
    ref.read(suggestProposalUseCaseProvider),
  ),
);

class ProposalsController extends StateNotifier<ProposalsState> {
  ProposalsController(
    this._getProposals,
    this._voteProposal,
    this._suggestProposal,
  ) : super(const ProposalsState());

  final GetProposalsUseCase _getProposals;
  final VoteProposalUseCase _voteProposal;
  final SuggestProposalUseCase _suggestProposal;

  Future<void> fetchProposals({bool refresh = false}) async {
    if (state.isLoading) return;
    final page = refresh ? 1 : state.currentPage;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final proposals = await _getProposals(page: page);
      state = state.copyWith(
        isLoading: false,
        proposals: refresh ? proposals : [...state.proposals, ...proposals],
        currentPage: page + 1,
        hasMore: proposals.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleVote(String proposalId, {required bool currentlyVoted}) async {
    try {
      final updated = await _voteProposal(proposalId, currentlyVoted: currentlyVoted);
      state = state.copyWith(
        proposals: state.proposals
            .map((p) => p.id == proposalId ? updated : p)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<bool> submitSuggestion({
    required String title,
    required String category,
    required String description,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _suggestProposal(
        title: title,
        category: category,
        description: description,
      );
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}
