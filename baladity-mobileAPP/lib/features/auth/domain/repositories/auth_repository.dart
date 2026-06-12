import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<({String token, UserEntity user})> login({
    required String email,
    required String password,
  });

  Future<({String token, UserEntity user})> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  });

  Future<void> logout();

  Future<UserEntity> getProfile();
}
