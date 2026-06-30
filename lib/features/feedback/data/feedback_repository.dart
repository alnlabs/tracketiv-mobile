import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/contracts/repository_contracts.dart';

class FeedbackRepository implements FeedbackRepositoryContract {
  FeedbackRepository(this._client);

  final SupabaseClient _client;

  Future<String> submitFeedback({
    required String type,
    required String message,
    String? contactEmail,
    String? displayName,
  }) async {
    final feedbackId = await _client.rpc('submit_feedback', params: {
      'p_type': type,
      'p_message': message,
      'p_contact_email': contactEmail,
    });

    final id = feedbackId as String;
    return id;
  }
}
