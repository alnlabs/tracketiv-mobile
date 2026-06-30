import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/offline_cache.dart';
import '../../../core/offline/offline_write_exception.dart';
import '../../../shared/utils/api_error_formatter.dart';
import '../../../shared/models/feed_item.dart';
import '../../../shared/utils/json_utils.dart';

class FeedRepository {
  FeedRepository(this._client, this._cache);

  final SupabaseClient _client;
  final OfflineCache _cache;

  Future<List<FeedItem>> getFeed({int limit = 50}) async {
    final cacheKey = 'feed_$limit';
    try {
      final data = await _client.rpc('get_my_feed', params: {'p_limit': limit});
      final rows = asJsonList(data).cast<Map<String, dynamic>>();
      await _cache.setJsonList(cacheKey, rows);
      return _parseFeedRows(rows);
    } catch (error) {
      if (!ApiErrorFormatter.isNetworkError(error)) rethrow;
      final cached = await _cache.getJsonList(cacheKey);
      if (cached != null) {
        return _parseFeedRows(cached.cast<Map<String, dynamic>>());
      }
      throw OfflineCacheMissException(
        'No cached feed. Connect to the internet and refresh.',
      );
    }
  }

  static List<FeedItem> _parseFeedRows(List<Map<String, dynamic>> rows) {
    final items = <FeedItem>[];
    for (final row in rows) {
      try {
        items.add(FeedItem.fromJson(row));
      } catch (_) {
        // Skip rows that fail to parse instead of failing the whole feed.
      }
    }
    return items;
  }

  Future<FeedItem?> getFeedPost(String logId) async {
    try {
      final data = await _client.rpc('get_feed_post', params: {'p_log_id': logId});
      final rows = asJsonList(data);
      if (rows.isEmpty) {
        await _cache.setJson('feed_post_$logId', {});
        return null;
      }
      await _cache.setJson('feed_post_$logId', rows.first);
      return FeedItem.fromJson(rows.first);
    } catch (error) {
      if (!ApiErrorFormatter.isNetworkError(error)) rethrow;
      final cached = await _cache.getJson('feed_post_$logId');
      if (cached == null) rethrow;
      if (cached.isEmpty) return null;
      return FeedItem.fromJson(cached);
    }
  }
}
