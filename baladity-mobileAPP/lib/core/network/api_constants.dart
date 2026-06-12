/// Central place for all API configuration.
///
/// To override the base URL at build time:
///   flutter run --dart-define=API_BASE_URL=https://your-domain.com/api
abstract class ApiConstants {
  // ─── Base URL ────────────────────────────────────────────────────────────────
  // Android emulator  → http://10.0.2.2:8000/api
  // iOS simulator     → http://localhost:8000/api
  // Physical device   → http://<your-machine-ip>:8000/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ─── Auth ────────────────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String profile = '/auth/user';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';

  // ─── Reports ─────────────────────────────────────────────────────────────────
  static const String reports = '/reports';

  // ─── Facilities ──────────────────────────────────────────────────────────────
  static const String facilities = '/facilities';
  static const String municipalities = '/municipalities';

  // ─── Projects ────────────────────────────────────────────────────────────────
  static const String projects = '/projects';

  // ─── Profile ─────────────────────────────────────────────────────────────────
  static const String userProfile = '/user/profile';
  static const String updateName = '/user/update-name';
  static const String changePassword = '/user/change-password';
  static const String updateProfileImage = '/user/update-profile-image';

  // ─── Proposals ───────────────────────────────────────────────────────────────
  static const String proposals = '/proposals';
  static const String proposalVote = '/proposals/{id}/vote';
  static const String suggestService = '/proposals/suggest';
}
