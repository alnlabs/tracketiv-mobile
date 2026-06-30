import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/contracts/repository_contracts.dart';
import '../../../core/offline/connectivity_provider.dart';
import '../../../core/offline/offline_cache.dart';
import '../../../core/offline/offline_fetch.dart';
import '../../../core/offline/offline_write_exception.dart';
import '../../../shared/utils/reactions.dart';
import '../../../shared/utils/supabase_embeds.dart';
import '../../../shared/models/log_comment.dart';
import '../../../shared/models/log_reaction.dart';

class SocialRepository implements SocialRepositoryContract {
  SocialRepository(
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

  Future<List<LogComment>> getComments(String logId) {
    return fetchListWithCache(
      cache: _cache,
      cacheKey: 'comments_$logId',
      emptyMessage: 'Comments are not available offline.',
      fetchRows: () async {
        final data = await _client
            .from('log_comments')
            .select(SupabaseEmbeds.commentWithAuthor)
            .eq('log_id', logId)
            .order('created_at');
        return (data as List).cast<Map<String, dynamic>>();
      },
      parse: LogComment.fromJson,
    );
  }

  Future<void> addComment({
    required String logId,
    required String authorId,
    required String body,
  }) async {
    await _requireOnline();
    await _client.from('log_comments').insert({
      'log_id': logId,
      'author_id': authorId,
      'body': body,
    });
  }

  Future<List<LogReaction>> getReactions(String logId) {
    return fetchListWithCache(
      cache: _cache,
      cacheKey: 'reactions_$logId',
      emptyMessage: 'Reactions are not available offline.',
      fetchRows: () async {
        final data = await _client
            .from('log_reactions')
            .select()
            .eq('log_id', logId);
        return (data as List).cast<Map<String, dynamic>>();
      },
      parse: LogReaction.fromJson,
    );
  }

  Future<List<ReactionSummary>> getReactionSummaries(
    String logId,
    String currentUserId,
  ) async {
    final reactions = await getReactions(logId);
    return Reactions.types.map((type) {
      final ofType = reactions.where((r) => r.emojiType == type).toList();
      return ReactionSummary(
        emojiType: type,
        count: ofType.length,
        reactedByMe: ofType.any((r) => r.userId == currentUserId),
      );
    }).toList();
  }

  Future<void> toggleReaction({
    required String logId,
    required String userId,
    required String emojiType,
  }) async {
    await _requireOnline();
    final existing = await _client
        .from('log_reactions')
        .select()
        .eq('log_id', logId)
        .eq('user_id', userId)
        .eq('emoji_type', emojiType)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('log_reactions')
          .delete()
          .eq('id', existing['id']);
    } else {
      await _client.from('log_reactions').insert({
        'log_id': logId,
        'user_id': userId,
        'emoji_type': emojiType,
      });
    }
  }
}
