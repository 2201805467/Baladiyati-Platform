import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;
  RegisterUseCase(this._repository);

  Future<({String token, UserEntity user})> call({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) =>
      _repository.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
}
