import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';

/// Admin console uses the main Supabase auth session plus an admin-mode flag.
final adminAuthRepositoryProvider = Provider((ref) {
  return ref.watch(authRepositoryProvider);
});

final adminAuthStateProvider = Provider((ref) {
  return ref.watch(authStateProvider);
});

final adminCurrentUserProvider = Provider((ref) {
  return ref.watch(currentUserProvider);
});

final adminCurrentProfileProvider = Provider((ref) {
  return ref.watch(currentProfileProvider);
});

final adminSessionIsAdminProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return profile?.isAdmin ?? false;
});
