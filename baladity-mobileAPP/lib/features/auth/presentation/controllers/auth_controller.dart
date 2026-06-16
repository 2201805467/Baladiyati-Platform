import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/logout_stream.dart';
import '../../../../core/utils/token_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'auth_state.dart';

// ─── Dependency Providers ─────────────────────────────────────────────────────

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final dioProvider = Provider(
  (ref) => DioClient.create(ref.read(tokenStorageProvider)),
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSourceImpl(ref.read(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.read(authRemoteDataSourceProvider),
    ref.read(tokenStorageProvider),
  ),
);

final loginUseCaseProvider = Provider(
  (ref) => LoginUseCase(ref.read(authRepositoryProvider)),
);

final registerUseCaseProvider = Provider(
  (ref) => RegisterUseCase(ref.read(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider(
  (ref) => LogoutUseCase(ref.read(authRepositoryProvider)),
);

// ─── Auth Controller ──────────────────────────────────────────────────────────

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  () => AuthController(),
);

class AuthController extends Notifier<AuthState> {
  late LoginUseCase _loginUseCase;
  late RegisterUseCase _registerUseCase;
  late LogoutUseCase _logoutUseCase;
  late TokenStorage _tokenStorage;
  late AuthRepository _repository;

  @override
  AuthState build() {
    _loginUseCase = ref.read(loginUseCaseProvider);
    _registerUseCase = ref.read(registerUseCaseProvider);
    _logoutUseCase = ref.read(logoutUseCaseProvider);
    _tokenStorage = ref.read(tokenStorageProvider);
    _repository = ref.read(authRepositoryProvider);
    
    _init();
    ref.read(tokenStorageProvider);
    forceLogoutStream.listen((_) => logout());
    
    return AuthState.initial();
  }

  /// Checks for a stored token on startup so GoRouter redirect fires correctly.
  Future<void> _init() async {
    final hasToken = await _tokenStorage.hasToken();
    state = hasToken
        ? AuthState.authenticated(const UserEntity.empty())
        : AuthState.unauthenticated();
  }

  Future<void> login({required String email, required String password}) async {
    state = AuthState.loading();
    try {
      final result = await _loginUseCase(email: email, password: password);
      state = AuthState.authenticated(result.user);
    } catch (e) {
      state = AuthState.withError(e.toString());
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    state = AuthState.loading();
    try {
      final result = await _registerUseCase(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      state = result.token.isNotEmpty
          ? AuthState.authenticated(result.user)
          : AuthState.otpPending(phone?.isNotEmpty == true ? phone! : email);
    } catch (e) {
      state = AuthState.withError(e.toString());
    }
  }

  Future<void> verifyOtp({
    required String identifier,
    required String otpCode,
  }) async {
    state = AuthState.loading();
    try {
      await refVerifyOtp(identifier: identifier, otpCode: otpCode);
      state = AuthState.otpVerified();
    } catch (e) {
      state = AuthState.withError(e.toString());
    }
  }

  Future<void> resendOtp({required String identifier}) async {
    try {
      await refResendOtp(identifier: identifier);
    } catch (e) {
      state = AuthState.withError(e.toString());
    }
  }

  Future<void> refVerifyOtp({
    required String identifier,
    required String otpCode,
  }) => _repository.verifyOtp(
    identifier: identifier,
    otpCode: otpCode,
    purpose: 'registration',
  );

  Future<void> refResendOtp({required String identifier}) =>
      _repository.resendOtp(identifier: identifier, purpose: 'registration');

  Future<void> bypassLogin() async {
    await _tokenStorage.saveToken('bypass-test-token');
    state = AuthState.authenticated(const UserEntity.empty());
  }

  Future<void> logout() async {
    try {
      await _logoutUseCase();
    } catch (_) {
      await _tokenStorage.clearAll();
    }
    state = AuthState.unauthenticated();
  }
}
