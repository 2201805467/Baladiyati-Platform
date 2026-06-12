import '../repositories/profile_repository.dart';

class ChangePasswordUseCase {
  final ProfileRepository _repository;
  ChangePasswordUseCase(this._repository);

  Future<void> call({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) =>
      _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );
}
