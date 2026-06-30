import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/repository_contracts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/offline/connectivity_provider.dart';
import '../../../core/offline/offline_provider.dart';
import '../data/profile_repository.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/models/profile_stats.dart';

final profileRepositoryProvider = Provider<ProfileRepositoryContract>((ref) {
  return ProfileRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(offlineCacheProvider),
    ref.watch(connectivityServiceProvider),
  );
});

final currentProfileProvider = FutureProvider<Profile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(null);
  return ref.watch(profileRepositoryProvider).getProfile(user.id);
});

final userProfileProvider = FutureProvider.family<Profile?, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).getProfile(userId);
});

final userProfileStatsProvider = FutureProvider.family<ProfileStats?, String>((ref, userId) {
  return ref.watch(profileRepositoryProvider).getProfileStats(userId);
});
