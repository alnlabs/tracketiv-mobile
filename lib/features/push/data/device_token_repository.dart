import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceTokenRepository {
  DeviceTokenRepository(this._client);

  final SupabaseClient _client;

  Future<void> upsertToken({
    required String token,
    required String platform,
  }) async {
    await _client.rpc('upsert_device_token', params: {
      'p_token': token,
      'p_platform': platform,
    });
  }

  Future<void> removeToken(String token) async {
    await _client.rpc('remove_device_token', params: {
      'p_token': token,
    });
  }
}
