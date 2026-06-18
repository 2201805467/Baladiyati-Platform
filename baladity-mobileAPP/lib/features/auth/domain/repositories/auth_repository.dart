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

  Future<void> verifyOtp({
    required String identifier,
    required String otpCode,
    String purpose,
  });

  Future<void> resendOtp({required String identifier, String purpose});

  Future<void> forgotPassword({required String email});

  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String password,
  });
}
