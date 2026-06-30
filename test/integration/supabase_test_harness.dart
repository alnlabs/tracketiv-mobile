import 'dart:io';

import 'package:supabase/supabase.dart';

import 'supabase_test_config.dart';

/// Boots a real local Supabase client for integration tests.
///
/// Uses the plain `supabase` Dart client — not `supabase_flutter` — so tests
/// avoid SharedPreferences / plugin dependencies and work under `flutter test`.
class SupabaseTestHarness {
  SupabaseTestHarness._();

  static SupabaseClient? _client;

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

  static Future<SupabaseClient> client() async {
    _client ??= SupabaseClient(
      SupabaseTestConfig.url,
      SupabaseTestConfig.anonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    return _client!;
  }

  static Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final c = await client();
    await c.auth.signOut();
    final response = await c.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw StateError('Sign-in failed for $email');
    }
    return user;
  }

  static Future<void> signOut() async {
    await (await client()).auth.signOut();
  }
}
