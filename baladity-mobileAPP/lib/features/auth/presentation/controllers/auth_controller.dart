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

final loginUseCaseProvider =
    Provider((ref) => LoginUseCase(ref.read(authRepositoryProvider)));

final registerUseCaseProvider =
    Provider((ref) => RegisterUseCase(ref.read(authRepositoryProvider)));

final logoutUseCaseProvider =
    Provider((ref) => LogoutUseCase(ref.read(authRepositoryProvider)));

// ─── Auth Controller ──────────────────────────────────────────────────────────

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.read(loginUseCaseProvider),
    ref.read(registerUseCaseProvider),
    ref.read(logoutUseCaseProvider),
    ref.read(tokenStorageProvider),
  ),
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._loginUseCase,
    this._registerUseCase,
    this._logoutUseCase,
    this._tokenStorage,
  ) : super(AuthState.initial()) {
    _init();
    forceLogoutStream.listen((_) => logout());
  }

  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final TokenStorage _tokenStorage;

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
      state = AuthState.authenticated(result.user);
    } catch (e) {
      state = AuthState.withError(e.toString());
    }
  }

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
