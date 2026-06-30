import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin/admin_otp_pending.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/admin_auth_security_repository.dart';

final adminAuthSecurityRepositoryProvider = Provider<AdminAuthSecurityRepository>((ref) {
  return AdminAuthSecurityRepository(ref.watch(supabaseClientProvider));
});

class AdminOtpPendingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => AdminOtpPending.isPending();

  Future<void> setPending(bool pending) async {
    await AdminOtpPending.setPending(pending);
    state = AsyncData(pending);
  }

  Future<void> clear() => setPending(false);
}

final adminOtpPendingProvider =
    AsyncNotifierProvider<AdminOtpPendingNotifier, bool>(AdminOtpPendingNotifier.new);

String maskEmail(String? email) {
  if (email == null || email.isEmpty) return 'your email';
  final parts = email.split('@');
  if (parts.length != 2 || parts[0].isEmpty) return 'your email';
  final local = parts[0];
  final masked = local.length <= 1 ? '*' : '${local[0]}${'*' * (local.length - 1)}';
  return '$masked@${parts[1]}';
}
