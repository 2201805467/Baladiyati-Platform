/// Central definition of all named route paths.
abstract class AppRoutes {
  // ─── Auth ─────────────────────────────────────────────────────────────────
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String otpVerification = '/otp-verification';
  static const String resetPassword = '/reset-password';

  // ─── Main ─────────────────────────────────────────────────────────────────
  static const String home = '/home';

  // ─── Reports ──────────────────────────────────────────────────────────────
  static const String reports = '/reports';
  static const String addReport = '/reports/add';

  // ─── Facilities ───────────────────────────────────────────────────────────
  static const String facilities = '/facilities';

  // ─── Projects ─────────────────────────────────────────────────────────────
  static const String projects = '/projects';

  // ─── Profile ──────────────────────────────────────────────────────────────
  static const String profile = '/profile';

  // ─── Emergency ────────────────────────────────────────────────────────────
  static const String emergency = '/emergency';

  // ─── Proposals ────────────────────────────────────────────────────────────
  static const String proposals = '/proposals';
  static const String proposalDetails = '/proposals/details';
  static const String suggestService = '/proposals/suggest';
}
