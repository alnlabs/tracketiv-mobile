import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gotrue/gotrue.dart' show AuthChangeEvent, AuthState;
import 'package:supabase/supabase.dart';
import 'package:tracketiv/core/crash/crash_reporter.dart';
import 'package:tracketiv/core/offline/connectivity_provider.dart';
import 'package:tracketiv/core/offline/offline_cache.dart';
import 'package:tracketiv/core/offline/offline_provider.dart';
import 'package:tracketiv/core/router/app_router.dart';
import 'package:tracketiv/features/admin/providers/admin_auth_provider.dart';
import 'package:tracketiv/features/admin/providers/admin_otp_provider.dart';
import 'package:tracketiv/features/admin/providers/admin_session_provider.dart';
import 'package:tracketiv/features/auth/providers/auth_provider.dart';
import 'package:tracketiv/features/notifications/providers/notification_provider.dart';
import 'package:tracketiv/features/onboarding/providers/onboarding_provider.dart';
import 'package:tracketiv/features/push/providers/push_provider.dart';
import 'package:tracketiv/features/reminders/providers/reminder_provider.dart';
import 'package:tracketiv/main.dart';

import '../integration/real_http.dart';
import '../integration/supabase_test_config.dart';
import '../integration/supabase_test_harness.dart';
import 'e2e_http.dart';
import 'e2e_path_provider.dart';
import 'e2e_screen_catalog.dart';

/// Roles exercised in the role × screen matrix.
enum E2eRole {
  guest,
  outsider,
  member,
  owner,
  admin,
}

class E2eLaunchOptions {
  const E2eLaunchOptions({
    required this.role,
    this.onboardingCompleted = true,
    this.adminConsoleActive = false,
  });

  final E2eRole role;
  final bool onboardingCompleted;
  final bool adminConsoleActive;
}

class E2eBootstrap {
  E2eBootstrap._();

  static bool _envReady = false;
  static Directory? _cacheDir;

  static Future<Directory> cacheDirectory() async {
    _cacheDir ??= await Directory.systemTemp.createTemp('tracketiv_e2e_cache_');
    return _cacheDir!;
  }

  static Future<bool> isLocalStackRunning() async {
    try {
      final client = HttpClient();
      try {
        final request =
            await client.getUrl(Uri.parse('${SupabaseTestConfig.url}/rest/v1/'));
        final response =
            await request.close().timeout(const Duration(seconds: 3));
        return response.statusCode < 500;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> launchApp(
    WidgetTester tester,
    E2eLaunchOptions options, {
    bool useE2eHttp = false,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (useE2eHttp) {
      allowE2eHttpInTests();
    } else {
      allowRealHttpInTests();
    }
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;

    _loadEnv();

    late SupabaseClient client;
    Session? session;

    // Network I/O must run outside the widget test fake-async zone.
    await tester.runAsync(() async {
      if (useE2eHttp) {
        allowE2eHttpInTests();
      } else {
        allowRealHttpInTests();
      }
      _cacheDir ??= await Directory.systemTemp.createTemp('tracketiv_e2e_cache_');
      installE2ePathProvider(_cacheDir!.path);
      GoogleFonts.config.allowRuntimeFetching = true;
      client = await SupabaseTestHarness.client();
      await client.auth.signOut();

      if (options.role != E2eRole.guest) {
        final creds = _credentialsFor(options.role);
        final response = await client.auth.signInWithPassword(
          email: creds.email,
          password: SupabaseTestConfig.password,
        );
        session = response.session;
        if (session == null) {
          throw StateError('E2E sign-in failed for ${creds.email}');
        }
      }
    });

    CrashReporter.instance.configure(client);

    final isAdminRole = options.adminConsoleActive;
    final signedInUser = client.auth.currentUser;

    final overrides = <Override>[
      supabaseClientProvider.overrideWithValue(client),
      offlineCacheProvider.overrideWithValue(OfflineCache(directory: _cacheDir)),
      connectivityServiceProvider.overrideWith((ref) {
        final service = ConnectivityService.test();
        ref.onDispose(service.dispose);
        return service;
      }),
      onboardingCompletedProvider.overrideWith(
        (ref) => OnboardingNotifier(options.onboardingCompleted),
      ),
      notificationRealtimeProvider.overrideWith((ref) {}),
      pushRegistrationProvider.overrideWith((ref) {}),
      remindersSyncProvider.overrideWith((ref) {}),
      adminSessionIsAdminProvider.overrideWith(
        (ref) async => isAdminRole,
      ),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          session == null
              ? const AuthState(AuthChangeEvent.signedOut, null)
              : AuthState(AuthChangeEvent.signedIn, session),
        ),
      ),
    ];

    if (signedInUser != null) {
      overrides.add(currentUserProvider.overrideWithValue(signedInUser));
    }

    if (options.adminConsoleActive) {
      overrides.addAll([
        adminSessionActiveProvider.overrideWith(_E2eAdminSessionNotifier.new),
        adminOtpPendingProvider.overrideWith(_E2eAdminOtpNotifier.new),
      ]);
    } else {
      overrides.add(
        adminSessionActiveProvider.overrideWith(_E2eAdminSessionInactiveNotifier.new),
      );
      overrides.add(
        adminOtpPendingProvider.overrideWith(_E2eAdminOtpInactiveNotifier.new),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const TracketivApp(),
      ),
    );

    await pumpUntilSettled(tester);
  }

  static Future<void> visitScreen(
    WidgetTester tester,
    E2eScreen screen,
  ) async {
    await navigateTo(tester, screen.path, extra: screen.extra);
  }

  static Future<void> navigateTo(
    WidgetTester tester,
    String path, {
    Object? extra,
    bool push = false,
  }) async {
    final router = container(tester).read(routerProvider);

    if (push) {
      if (extra != null) {
        router.push(path, extra: extra);
      } else {
        router.push(path);
      }
    } else if (extra != null) {
      router.push(path, extra: extra);
    } else {
      router.go(path);
    }

    await pumpUntilSettled(tester);
  }

  static Future<void> pumpUntilSettled(WidgetTester tester, {int maxRounds = 30}) async {
    await tester.pump();
    for (var i = 0; i < maxRounds; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  static ProviderContainer container(WidgetTester tester) {
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  static void assertExpectation(
    WidgetTester tester,
    E2eExpectation expectation,
  ) {
    switch (expectation) {
      case E2eShowsText(:final text):
        expect(find.text(text), findsWidgets, reason: 'Expected "$text" on screen');
      case E2eShowsAnyText(:final texts):
        final found = texts.any((text) => find.text(text).evaluate().isNotEmpty);
        expect(found, isTrue, reason: 'Expected one of: ${texts.join(', ')}');
      case E2eRedirect(:final pathPrefix):
        final router = container(tester).read(routerProvider);
        final location = router.routerDelegate.currentConfiguration.uri.toString();
        expect(
          location.startsWith(pathPrefix) || location.contains(pathPrefix),
          isTrue,
          reason: 'Expected redirect to $pathPrefix, got $location',
        );
    }
  }

  static void _loadEnv() {
    if (_envReady) return;
    dotenv.testLoad(
      fileInput: 'SUPABASE_URL=${SupabaseTestConfig.url}\n'
          'SUPABASE_ANON_KEY=${SupabaseTestConfig.anonKey}\n',
    );
    _envReady = true;
  }

  static Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  static ({String email, String id}) _credentialsFor(E2eRole role) {
    return switch (role) {
      E2eRole.owner => (
          email: SupabaseTestConfig.ownerEmail,
          id: SupabaseTestConfig.ownerId,
        ),
      E2eRole.member => (
          email: SupabaseTestConfig.memberEmail,
          id: SupabaseTestConfig.memberId,
        ),
      E2eRole.outsider => (
          email: SupabaseTestConfig.outsiderEmail,
          id: SupabaseTestConfig.outsiderId,
        ),
      E2eRole.admin => (
          email: SupabaseTestConfig.adminEmail,
          id: SupabaseTestConfig.adminId,
        ),
      E2eRole.guest => throw ArgumentError('Guest has no credentials'),
    };
  }
}

class _E2eAdminSessionInactiveNotifier extends AdminSessionNotifier {
  @override
  Future<bool> build() async => false;
}

class _E2eAdminOtpInactiveNotifier extends AdminOtpPendingNotifier {
  @override
  Future<bool> build() async => false;
}

class _E2eAdminSessionNotifier extends AdminSessionNotifier {
  @override
  Future<bool> build() async => true;
}

class _E2eAdminOtpNotifier extends AdminOtpPendingNotifier {
  @override
  Future<bool> build() async => false;
}
