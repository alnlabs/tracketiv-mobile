import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/admin/admin_session.dart';
import 'core/config/env.dart';
import 'core/crash/crash_reporter.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'features/push/providers/push_provider.dart';
import 'features/push/services/push_notification_service.dart';
import 'features/reminders/services/notification_service.dart';

void main() {
  runZonedGuarded(
    () {
      _bootstrapApp();
    },
    (error, stack) {
      CrashReporter.instance.capture(
        error: error,
        stack: stack,
        errorType: 'zone',
      );
    },
  );
}

Future<void> _bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Failed to load .env: $e');
  }

  if (!Env.isConfigured) {
    runApp(const ProviderScope(child: MissingConfigApp()));
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: false,
    ),
  );

  if (kIsWeb) {
    await _recoverWebAuthSession();
  }

  if (!kIsWeb) {
    await NotificationService.instance.initialize();
    if (Env.pushNotificationsEnabled) {
      await FirebaseBootstrap.initialize();
    }
    await PushNotificationService.instance.configure(Supabase.instance.client);
  }

  CrashReporter.instance.configure(Supabase.instance.client);
  await CrashReporter.loadAppVersion();
  CrashReporter.instance.install();
  CrashReporter.instance.setAdminMode(await AdminSession.isActive());

  final onboardingCompleted = await readOnboardingCompleted();

  runApp(
    ProviderScope(
      overrides: [
        onboardingCompletedProvider.overrideWith(
          (ref) => OnboardingNotifier(onboardingCompleted),
        ),
      ],
      child: const TracketivApp(),
    ),
  );
}

/// Only parse the URL when Supabase redirected back with auth params.
Future<void> _recoverWebAuthSession() async {
  final uri = Uri.base;
  if (!_hasAuthCallbackParams(uri)) return;

  try {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  } catch (e) {
    debugPrint('Web auth callback skipped: $e');
  }
}

bool _hasAuthCallbackParams(Uri uri) {
  final normalized = uri.hasQuery
      ? Uri.parse(uri.toString().replaceAll('#', '&'))
      : Uri.parse(uri.toString().replaceAll('#', '?'));

  final params = normalized.queryParameters;
  final code = params['code'];
  final accessToken = params['access_token'];

  return (code != null && code.isNotEmpty) ||
      (accessToken != null && accessToken.isNotEmpty) ||
      params.containsKey('error');
}

class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Missing Supabase config',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create tracketiv-mobile/.env from .env.example and set:\n'
                  '- SUPABASE_URL\n'
                  '- SUPABASE_ANON_KEY\n\n'
                  'Then restart the app (full restart, not hot reload).',
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 16),
                  Text('Web origin: ${Uri.base.origin}'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TracketivApp extends ConsumerWidget {
  const TracketivApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.read(routerProvider);
    configurePushNotificationNavigation(router);
    configureLocalReminderNavigation(router);

    return MaterialApp.router(
      title: 'Tracketiv',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
