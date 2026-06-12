import '../../../auth/domain/entities/user_entity.dart';

class ProfileState {
  final bool isLoadingProfile;
  final bool isSavingName;
  final bool isSavingPassword;
  final bool isSavingImage;
  final UserEntity? user;
  final String? errorMessage;
  final String? successMessage;

  const ProfileState({
    this.isLoadingProfile = false,
    this.isSavingName = false,
    this.isSavingPassword = false,
    this.isSavingImage = false,
    this.user,
    this.errorMessage,
    this.successMessage,
  });

  bool get isBusy =>
      isLoadingProfile || isSavingName || isSavingPassword || isSavingImage;

  ProfileState copyWith({
    bool? isLoadingProfile,
    bool? isSavingName,
    bool? isSavingPassword,
    bool? isSavingImage,
    UserEntity? user,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ProfileState(
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      isSavingName: isSavingName ?? this.isSavingName,
      isSavingPassword: isSavingPassword ?? this.isSavingPassword,
      isSavingImage: isSavingImage ?? this.isSavingImage,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}
