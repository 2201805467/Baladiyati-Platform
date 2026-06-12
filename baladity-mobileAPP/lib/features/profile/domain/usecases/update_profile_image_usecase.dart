import '../../../auth/domain/entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileImageUseCase {
  final ProfileRepository _repository;
  UpdateProfileImageUseCase(this._repository);

  Future<UserEntity> call({required String imagePath}) =>
      _repository.updateProfileImage(imagePath: imagePath);
}
