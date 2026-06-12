import '../../../auth/domain/entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateUsernameUseCase {
  final ProfileRepository _repository;
  UpdateUsernameUseCase(this._repository);

  Future<UserEntity> call({required String name}) =>
      _repository.updateUsername(name: name);
}
