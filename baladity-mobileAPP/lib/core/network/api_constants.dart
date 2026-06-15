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
  static const String profile = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String resetPassword = '/auth/reset-password';

  // ─── Reports ─────────────────────────────────────────────────────────────────
  static const String reports = '/citizen/reports';
  static const String reportSimilar = '/citizen/reports/similar';
  static const String reportClassifyImage = '/citizen/reports/classify-image';

  // ─── Facilities ──────────────────────────────────────────────────────────────
  static const String facilities = '/citizen/facilities';
  static const String municipalities = '/municipalities';

  // ─── Projects ────────────────────────────────────────────────────────────────
  static const String projects = '/citizen/projects';
  static const String emergencyContacts = '/citizen/emergency-contacts';

  // ─── Profile ─────────────────────────────────────────────────────────────────
  static const String userProfile = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String updateName = '/auth/profile';
  static const String changePassword = '/auth/change-password';
  static const String updateProfileImage = '/auth/profile';

  // ─── Proposals ───────────────────────────────────────────────────────────────
  static const String proposals = '/citizen/suggestions';
  static const String proposalVote = '/citizen/suggestions/{id}/vote';
  static const String suggestService = '/citizen/suggestions';
  static const String notifications = '/notifications';
}
