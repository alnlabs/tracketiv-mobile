import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/contracts/repository_contracts.dart';
import '../../../core/offline/connectivity_provider.dart';
import '../../../core/offline/offline_cache.dart';
import '../../../core/offline/offline_fetch.dart';
import '../../../core/offline/offline_write_exception.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/profile_stats.dart';

class ProfileUpdate {
  const ProfileUpdate({
    this.displayName,
    this.username,
    this.avatarUrl,
    this.bio,
    this.dateOfBirth,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.country,
    this.city,
    this.phone,
    this.weightUnit,
    this.clearBio = false,
    this.clearDateOfBirth = false,
    this.clearGender = false,
    this.clearHeight = false,
    this.clearWeight = false,
    this.clearCountry = false,
    this.clearCity = false,
    this.clearPhone = false,
  });

  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final DateTime? dateOfBirth;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? country;
  final String? city;
  final String? phone;
  final String? weightUnit;
  final bool clearBio;
  final bool clearDateOfBirth;
  final bool clearGender;
  final bool clearHeight;
  final bool clearWeight;
  final bool clearCountry;
  final bool clearCity;
  final bool clearPhone;
}

class ProfileRepository implements ProfileRepositoryContract {
  ProfileRepository(
    this._client,
    this._cache,
    this._connectivity,
  );

  final SupabaseClient _client;
  final OfflineCache _cache;
  final OnlineChecker _connectivity;

  Future<void> _requireOnline() async {
    if (!await _connectivity.checkOnline()) {
      throw const OfflineWriteException();
    }
  }

  Future<Profile?> getProfile(String userId) {
    return fetchOptionalWithCache(
      cache: _cache,
      cacheKey: 'profile_$userId',
      fetchRow: () async {
        final data = await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (data == null) return null;
        return Map<String, dynamic>.from(data);
      },
      parse: Profile.fromJson,
    );
  }

  Future<ProfileStats?> getProfileStats(String userId) async {
    final data = await _client.rpc('get_user_profile_stats', params: {'p_user_id': userId});
    if (data == null) return null;
    return ProfileStats.fromJson(data as Map<String, dynamic>);
  }

  Future<Profile> updateProfile({
    required String userId,
    required ProfileUpdate update,
  }) async {
    await _requireOnline();
    if (update.username != null) {
      final normalized = update.username!.trim().toLowerCase();
      final available = await _client.rpc(
        'is_username_available',
        params: {'p_username': normalized, 'p_user_id': userId},
      );
      if (available != true) {
        throw const AuthException('Username is already taken');
      }
    }

    final updates = <String, dynamic>{};
    if (update.displayName != null) updates['display_name'] = update.displayName!.trim();
    if (update.username != null) updates['username'] = update.username!.trim().toLowerCase();
    if (update.avatarUrl != null) updates['avatar_url'] = update.avatarUrl;
    if (update.bio != null || update.clearBio) updates['bio'] = update.clearBio ? null : update.bio?.trim();
    if (update.dateOfBirth != null || update.clearDateOfBirth) {
      updates['date_of_birth'] = update.clearDateOfBirth
          ? null
          : update.dateOfBirth!.toIso8601String().split('T').first;
    }
    if (update.gender != null || update.clearGender) {
      updates['gender'] = update.clearGender ? null : update.gender;
    }
    if (update.heightCm != null || update.clearHeight) {
      updates['height_cm'] = update.clearHeight ? null : update.heightCm;
    }
    if (update.weightKg != null || update.clearWeight) {
      updates['weight_kg'] = update.clearWeight ? null : update.weightKg;
    }
    if (update.country != null || update.clearCountry) {
      updates['country'] = update.clearCountry ? null : update.country!.trim();
    }
    if (update.city != null || update.clearCity) {
      updates['city'] = update.clearCity ? null : update.city!.trim();
    }
    if (update.phone != null || update.clearPhone) {
      updates['phone'] = update.clearPhone ? null : update.phone!.trim();
    }
    if (update.weightUnit != null) updates['weight_unit'] = update.weightUnit;

    final data = await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
    final profile = Profile.fromJson(data);
    await _cache.setJson('profile_$userId', data);
    return profile;
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _requireOnline();
    final path = '$userId/$fileName';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}
