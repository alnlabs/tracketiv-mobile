import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/repository_contracts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/feedback_repository.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepositoryContract>((ref) {
  return FeedbackRepository(ref.watch(supabaseClientProvider));
});
