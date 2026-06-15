import '../../domain/entities/user_entity.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  otpPending,
  otpVerified,
  error,
}

class AuthState {
  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;
  final String? otpIdentifier;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.otpIdentifier,
  });

  static AuthState initial() => const AuthState(status: AuthStatus.initial);
  static AuthState loading() => const AuthState(status: AuthStatus.loading);
  static AuthState unauthenticated() =>
      const AuthState(status: AuthStatus.unauthenticated);
  static AuthState authenticated(UserEntity user) =>
      AuthState(status: AuthStatus.authenticated, user: user);
  static AuthState otpPending(String identifier) =>
      AuthState(status: AuthStatus.otpPending, otpIdentifier: identifier);
  static AuthState otpVerified() =>
      const AuthState(status: AuthStatus.otpVerified);
  static AuthState withError(String message) =>
      AuthState(status: AuthStatus.error, errorMessage: message);

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
}
