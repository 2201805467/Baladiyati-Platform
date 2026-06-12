import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _dataSource;
  ProfileRepositoryImpl(this._dataSource);

  @override
  Future<UserEntity> getProfile() => _dataSource.getProfile();

  @override
  Future<UserEntity> updateUsername({required String name}) =>
      _dataSource.updateUsername(name: name);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) =>
      _dataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );

  @override
  Future<UserEntity> updateProfileImage({required String imagePath}) =>
      _dataSource.updateProfileImage(imagePath: imagePath);
}
