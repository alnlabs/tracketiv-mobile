import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../crash/crash_reporter.dart';
import '../../features/admin/providers/admin_auth_provider.dart';
import '../../features/admin/providers/admin_provider.dart';
import '../../features/admin/providers/admin_otp_provider.dart';
import '../../features/admin/providers/admin_session_provider.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Keeps [GoRouter] alive while auth changes only re-run [redirect].
class AppRouterNotifier extends ChangeNotifier {
  AppRouterNotifier(this._ref) {
    _ref.listen(onboardingCompletedProvider, (_, __) => notifyListeners());
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(adminSessionActiveProvider, (_, __) => notifyListeners());
    _ref.listen(adminOtpPendingProvider, (_, __) => notifyListeners());
    _ref.listen(adminSessionIsAdminProvider, (_, __) => notifyListeners());
    _ref.listen(mainSessionIsAdminProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(GoRouterState state) {
    CrashReporter.instance.setCurrentRoute(state.uri.toString());
    final location = state.uri.path;
    final isAdminRoute = location.startsWith('/admin');
    final isAdminLogin = location == '/admin/login';
    final isAdminVerifyOtp = location == '/admin/verify-otp';

    final authState = _ref.read(authStateProvider);
    final isLoggedIn = authState.valueOrNull?.session != null;
    final adminMode = _ref.read(adminSessionActiveProvider).valueOrNull ?? false;
    final otpPending = _ref.read(adminOtpPendingProvider).valueOrNull ?? false;
    final adminIsAdminAsync = _ref.read(adminSessionIsAdminProvider);
    final adminIsAdmin = adminIsAdminAsync.valueOrNull;

    if (isAdminRoute) {
      if (authState.isLoading ||
          (isLoggedIn && adminIsAdminAsync.isLoading && !isAdminLogin && !isAdminVerifyOtp)) {
        return null;
      }

      if (isAdminVerifyOtp) {
        if (!isLoggedIn || adminIsAdmin != true) return '/admin/login';
        if (!otpPending && adminMode) return '/admin';
        if (!otpPending && !adminMode) return '/admin/login';
        return null;
      }

      if (!isAdminLogin) {
        if (!isLoggedIn) return '/admin/login';
        if (otpPending) return '/admin/verify-otp';
        if (!adminMode) return '/admin/login';
        if (adminIsAdmin == false) return '/admin/login';
      }

      if (isAdminLogin && isLoggedIn && adminIsAdmin == true) {
        if (otpPending) return '/admin/verify-otp';
        if (adminMode) return '/admin';
      }

      return null;
    }

    if (isLoggedIn && otpPending && !adminMode) {
      if (adminIsAdminAsync.isLoading) return null;
      if (adminIsAdmin == true && !isAdminRoute) return '/admin/verify-otp';
    }

    final mainIsAdminAsync = _ref.read(mainSessionIsAdminProvider);
    final isLoading = authState.isLoading;
    final isAuthRoute = location == '/login' ||
        location == '/register' ||
        location == '/forgot-password' ||
        location == '/reset-password';
    final isLegalRoute = isOnboardingPublicRoute(location);
    final isOnboardingRoute = location == '/onboarding';

    if (adminMode && isLoggedIn) {
      return '/admin';
    }

    final onboardingAsync = _ref.read(onboardingCompletedProvider);
    final onboardingDone = onboardingAsync.valueOrNull ?? false;

    if (!isLoggedIn && onboardingAsync.isLoading && !isAdminRoute) {
      return null;
    }

    if (!isLoggedIn && !onboardingDone && !isOnboardingRoute && !isLegalRoute && !isAdminRoute) {
      return '/onboarding';
    }

    if (!isLoggedIn && onboardingDone && isOnboardingRoute) {
      return '/login';
    }

    if (location == '/' || location.isEmpty) {
      if (isLoading) return onboardingDone ? '/login' : '/onboarding';
      return isLoggedIn ? '/home' : (onboardingDone ? '/login' : '/onboarding');
    }

    if (isLoading) return null;

    final mainIsAdmin = mainIsAdminAsync.valueOrNull ?? false;
    if (isLoggedIn && mainIsAdmin) {
      if (otpPending && !adminMode) return '/admin/verify-otp';
      if (!isAuthRoute) return '/login?blocked=admin';
    }

    if (isLoggedIn && isOnboardingRoute) {
      return '/home';
    }

    if (!isLoggedIn && !isAuthRoute && !isLegalRoute && !isOnboardingRoute) {
      return onboardingDone ? '/login' : '/onboarding';
    }
    if (isLoggedIn && isAuthRoute && location != '/reset-password') {
      return '/home';
    }
    return null;
  }
}

final appRouterNotifierProvider = Provider<AppRouterNotifier>((ref) {
  final notifier = AppRouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});
