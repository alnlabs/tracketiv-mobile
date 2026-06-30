import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAuthSecurityRepository {
  AdminAuthSecurityRepository(this._client);

  final SupabaseClient _client;

  Future<bool> isDeviceTrusted(String deviceId) async {
    final result = await _client.rpc(
      'admin_is_device_trusted',
      params: {'p_device_id': deviceId},
    );
    return result == true;
  }

  Future<AdminOtpSendResult> sendLoginOtp(String deviceId) async {
    final data = await _client.rpc(
      'admin_send_login_otp',
      params: {'p_device_id': deviceId},
    );

    if (data is! Map<String, dynamic>) {
      return const AdminOtpSendResult();
    }

    return AdminOtpSendResult(
      alreadyTrusted: data['alreadyTrusted'] == true,
      emailHint: data['emailHint'] as String?,
      expiresInMinutes: data['expiresInMinutes'] as int?,
    );
  }

  Future<void> verifyLoginOtp({
    required String deviceId,
    required String code,
  }) async {
    final result = await _client.rpc(
      'admin_verify_login_otp',
      params: {
        'p_device_id': deviceId,
        'p_code': code.trim(),
      },
    );
    if (result != true) {
      throw const AuthException('Verification failed');
    }
  }
}

class AdminOtpSendResult {
  const AdminOtpSendResult({
    this.alreadyTrusted = false,
    this.emailHint,
    this.expiresInMinutes,
  });

  final bool alreadyTrusted;
  final String? emailHint;
  final int? expiresInMinutes;
}
