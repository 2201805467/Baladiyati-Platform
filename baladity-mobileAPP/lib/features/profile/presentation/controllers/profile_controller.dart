import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories_impl/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/update_profile_image_usecase.dart';
import '../../domain/usecases/update_username_usecase.dart';
import 'profile_state.dart';

// ─── Dependency Providers ─────────────────────────────────────────────────────

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSourceImpl(ref.read(dioProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.read(profileRemoteDataSourceProvider)),
);

final getProfileUseCaseProvider = Provider(
  (ref) => GetProfileUseCase(ref.read(profileRepositoryProvider)),
);

final updateUsernameUseCaseProvider = Provider(
  (ref) => UpdateUsernameUseCase(ref.read(profileRepositoryProvider)),
);

final changePasswordUseCaseProvider = Provider(
  (ref) => ChangePasswordUseCase(ref.read(profileRepositoryProvider)),
);

final updateProfileImageUseCaseProvider = Provider(
  (ref) => UpdateProfileImageUseCase(ref.read(profileRepositoryProvider)),
);

// ─── Controller Provider ──────────────────────────────────────────────────────

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>(
  (ref) => ProfileController(
    ref.read(getProfileUseCaseProvider),
    ref.read(updateUsernameUseCaseProvider),
    ref.read(changePasswordUseCaseProvider),
    ref.read(updateProfileImageUseCaseProvider),
    initialUser: ref.read(authControllerProvider).user,
  ),
);

// ─── Controller ───────────────────────────────────────────────────────────────

class ProfileController extends StateNotifier<ProfileState> {
  final GetProfileUseCase _getProfile;
  final UpdateUsernameUseCase _updateUsername;
  final ChangePasswordUseCase _changePassword;
  final UpdateProfileImageUseCase _updateProfileImage;

  ProfileController(
    this._getProfile,
    this._updateUsername,
    this._changePassword,
    this._updateProfileImage, {
    initialUser,
  }) : super(ProfileState(user: initialUser));

  // ─── Fetch Profile ────────────────────────────────────────────────────────

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoadingProfile: true, clearError: true);
    try {
      final user = await _getProfile();
      state = state.copyWith(isLoadingProfile: false, user: user);
    } catch (e) {
      // In dev mode (no backend), keep the existing user and silently fail
      state = state.copyWith(isLoadingProfile: false);
    }
  }

  // ─── Update Username ──────────────────────────────────────────────────────

  Future<bool> updateUsername({required String name}) async {
    state = state.copyWith(isSavingName: true, clearError: true, clearSuccess: true);
    try {
      final updated = await _updateUsername(name: name);
      state = state.copyWith(
        isSavingName: false,
        user: updated,
        successMessage: 'تم تحديث الاسم بنجاح',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSavingName: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  // ─── Change Password ──────────────────────────────────────────────────────

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    state = state.copyWith(isSavingPassword: true, clearError: true, clearSuccess: true);
    try {
      await _changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );
      state = state.copyWith(
        isSavingPassword: false,
        successMessage: 'تم تغيير كلمة المرور بنجاح',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSavingPassword: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  // ─── Update Profile Image ─────────────────────────────────────────────────

  Future<void> updateProfileImage({required String imagePath}) async {
    state = state.copyWith(isSavingImage: true, clearError: true, clearSuccess: true);
    try {
      final updated = await _updateProfileImage(imagePath: imagePath);
      state = state.copyWith(
        isSavingImage: false,
        user: updated,
        successMessage: 'تم تحديث الصورة الشخصية بنجاح',
      );
    } catch (e) {
      state = state.copyWith(
        isSavingImage: false,
        errorMessage: e.toString(),
      );
    }
  }
}
