import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/auth_state.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/registration_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/proposals/domain/entities/proposal_entity.dart';
import '../../features/proposals/presentation/pages/proposal_details_page.dart';
import '../../features/proposals/presentation/pages/suggest_service_page.dart';
import '../../features/emergency/presentation/pages/emergency_numbers_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reports/presentation/pages/add_report_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import 'app_routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    refreshListenable: notifier,
    redirect: notifier._redirect,
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegistrationPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        builder: (context, state) => OtpVerificationPage(
          phoneNumber: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => ResetPasswordPage(
          phoneNumber: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => const ReportsPage(),
      ),
      GoRoute(
        path: AppRoutes.addReport,
        builder: (context, state) => const AddReportPage(),
      ),
      GoRoute(
        path: AppRoutes.proposalDetails,
        builder: (context, state) => ProposalDetailsPage(
          proposal: state.extra as ProposalEntity,
        ),
      ),
      GoRoute(
        path: AppRoutes.suggestService,
        builder: (context, state) => const SuggestServicePage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.emergency,
        builder: (context, state) => const EmergencyNumbersPage(),
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  String? _redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authControllerProvider);
    final loc = state.matchedLocation;

    final isAuthPage = loc == AppRoutes.login ||
        loc == AppRoutes.register ||
        loc == AppRoutes.forgotPassword ||
        loc == AppRoutes.otpVerification ||
        loc == AppRoutes.resetPassword;

    if (authState.status == AuthStatus.initial) return null;

    if (!authState.isAuthenticated && !isAuthPage) return AppRoutes.login;
    if (authState.isAuthenticated && isAuthPage) return AppRoutes.home;

    return null;
  }
}
