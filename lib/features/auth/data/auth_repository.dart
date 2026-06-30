import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<bool> isUsernameAvailable(String username, {String? excludeUserId}) async {
    final result = await _client.rpc(
      'is_username_available',
      params: {
        'p_username': username.trim().toLowerCase(),
        'p_user_id': excludeUserId,
      },
    );
    return result == true;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    final available = await isUsernameAvailable(normalizedUsername);
    if (!available) {
      throw const AuthException('Username is already taken');
    }

    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'username': normalizedUsername,
        'display_name': displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : normalizedUsername,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    final email = await _client.rpc(
      'get_email_for_login',
      params: {'p_identifier': emailOrUsername.trim()},
    );

    if (email == null || (email as String).isEmpty) {
      throw const AuthException('Invalid login credentials');
    }

    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: Env.passwordResetRedirect,
    );
  }

  Future<UserResponse> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }
}
