import '../../../../core/utils/token_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _dataSource;
  final TokenStorage _tokenStorage;

  AuthRepositoryImpl(this._dataSource, this._tokenStorage);

  @override
  Future<({String token, UserEntity user})> login({
    required String email,
    required String password,
  }) async {
    final response = await _dataSource.login(email: email, password: password);
    await _tokenStorage.saveToken(response.token);
    await _tokenStorage.saveUserId(response.user.id.toString());
    return (token: response.token, user: response.user as UserEntity);
  }

  @override
  Future<({String token, UserEntity user})> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _dataSource.register(
      name: name,
      email: email,
      password: password,
      phone: phone,
    );
    if (response.token.isNotEmpty) {
      await _tokenStorage.saveToken(response.token);
      await _tokenStorage.saveUserId(response.user.id.toString());
    }
    return (token: response.token, user: response.user as UserEntity);
  }

  @override
  Future<void> logout() async {
    try {
      await _dataSource.logout();
    } finally {
      await _tokenStorage.clearAll();
    }
  }

  @override
  Future<UserEntity> getProfile() => _dataSource.getProfile();

  @override
  Future<void> verifyOtp({
    required String identifier,
    required String otpCode,
    String purpose = 'registration',
  }) => _dataSource.verifyOtp(
    identifier: identifier,
    otpCode: otpCode,
    purpose: purpose,
  );

  @override
  Future<void> resendOtp({
    required String identifier,
    String purpose = 'registration',
  }) => _dataSource.resendOtp(identifier: identifier, purpose: purpose);
}
