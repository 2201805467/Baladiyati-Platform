import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/facilities_remote_datasource.dart';
import '../../data/repositories_impl/facilities_repository_impl.dart';
import '../../domain/repositories/facilities_repository.dart';
import '../../domain/usecases/get_facilities_usecase.dart';
import 'facilities_state.dart';

final facilitiesRemoteDataSourceProvider = Provider<FacilitiesRemoteDataSource>(
  (ref) => FacilitiesRemoteDataSourceImpl(ref.read(dioProvider)),
);

final facilitiesRepositoryProvider = Provider<FacilitiesRepository>(
  (ref) => FacilitiesRepositoryImpl(ref.read(facilitiesRemoteDataSourceProvider)),
);

final getFacilitiesUseCaseProvider = Provider<GetFacilitiesUseCase>(
  (ref) => GetFacilitiesUseCase(ref.read(facilitiesRepositoryProvider)),
);

final facilitiesControllerProvider =
    StateNotifierProvider<FacilitiesController, FacilitiesState>(
  (ref) => FacilitiesController(ref.read(getFacilitiesUseCaseProvider)),
);

class FacilitiesController extends StateNotifier<FacilitiesState> {
  final GetFacilitiesUseCase _getFacilities;

  FacilitiesController(this._getFacilities) : super(const FacilitiesState());

  Future<void> fetchFacilities({
    String? type,
    int? municipalityId,
    bool refresh = false,
  }) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.currentPage;
    if (!refresh && !state.hasMore) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await _getFacilities(
        type: type == 'الكل' ? null : type,
        municipalityId: municipalityId,
        page: page,
      );

      final updated = refresh ? results : [...state.facilities, ...results];
      state = state.copyWith(
        isLoading: false,
        facilities: updated,
        hasMore: results.isNotEmpty,
        currentPage: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}
