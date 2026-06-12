import '../../domain/entities/facility_entity.dart';

class FacilitiesState {
  final bool isLoading;
  final List<FacilityEntity> facilities;
  final String? errorMessage;
  final String? selectedType;
  final bool hasMore;
  final int currentPage;

  const FacilitiesState({
    this.isLoading = false,
    this.facilities = const [],
    this.errorMessage,
    this.selectedType,
    this.hasMore = true,
    this.currentPage = 1,
  });

  FacilitiesState copyWith({
    bool? isLoading,
    List<FacilityEntity>? facilities,
    String? errorMessage,
    bool clearError = false,
    String? selectedType,
    bool clearType = false,
    bool? hasMore,
    int? currentPage,
  }) {
    return FacilitiesState(
      isLoading: isLoading ?? this.isLoading,
      facilities: facilities ?? this.facilities,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}
