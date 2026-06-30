import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/repository_contracts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/offline/connectivity_provider.dart';
import '../../../core/offline/offline_provider.dart';
import '../data/social_repository.dart';
import '../../../shared/models/log_comment.dart';
import '../../../shared/models/log_reaction.dart';

final socialRepositoryProvider = Provider<SocialRepositoryContract>((ref) {
  return SocialRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(offlineCacheProvider),
    ref.watch(connectivityServiceProvider),
  );
});

final logCommentsProvider = FutureProvider.family<List<LogComment>, String>((ref, logId) {
  return ref.watch(socialRepositoryProvider).getComments(logId);
});

final logReactionsProvider = FutureProvider.family<List<ReactionSummary>, String>((ref, logId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(socialRepositoryProvider).getReactionSummaries(logId, user.id);
});
