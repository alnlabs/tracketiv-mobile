import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/social_repository.dart';
import '../../../shared/models/log_comment.dart';
import '../../../shared/models/log_reaction.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(ref.watch(supabaseClientProvider));
});

final logCommentsProvider = FutureProvider.family<List<LogComment>, String>((ref, logId) {
  return ref.watch(socialRepositoryProvider).getComments(logId);
});

final logReactionsProvider = FutureProvider.family<List<ReactionSummary>, String>((ref, logId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(socialRepositoryProvider).getReactionSummaries(logId, user.id);
});
