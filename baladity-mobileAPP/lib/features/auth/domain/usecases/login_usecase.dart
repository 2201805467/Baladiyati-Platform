import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;
  LoginUseCase(this._repository);

  Future<({String token, UserEntity user})> call({
    required String email,
    required String password,
  }) =>
      _repository.login(email: email, password: password);
}
