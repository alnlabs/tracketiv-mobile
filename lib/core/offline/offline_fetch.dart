import '../../shared/utils/api_error_formatter.dart';
import 'offline_write_exception.dart';
import 'offline_cache.dart';

Future<List<T>> fetchListWithCache<T>({
  required OfflineCache cache,
  required String cacheKey,
  required Future<List<Map<String, dynamic>>> Function() fetchRows,
  required T Function(Map<String, dynamic> json) parse,
  String emptyMessage = 'No cached data. Connect to the internet and try again.',
}) async {
  try {
    final rows = await fetchRows();
    await cache.setJsonList(cacheKey, rows);
    return rows.map(parse).toList();
  } catch (error) {
    if (!ApiErrorFormatter.isNetworkError(error)) rethrow;
    final cached = await cache.getJsonList(cacheKey);
    if (cached != null) {
      return cached.map(parse).toList();
    }
    throw OfflineCacheMissException(emptyMessage);
  }
}

Future<T> fetchObjectWithCache<T>({
  required OfflineCache cache,
  required String cacheKey,
  required Future<Map<String, dynamic>> Function() fetchRow,
  required T Function(Map<String, dynamic> json) parse,
  String emptyMessage = 'No cached data. Connect to the internet and try again.',
}) async {
  try {
    final row = await fetchRow();
    await cache.setJson(cacheKey, row);
    return parse(row);
  } catch (error) {
    if (!ApiErrorFormatter.isNetworkError(error)) rethrow;
    final cached = await cache.getJson(cacheKey);
    if (cached != null) {
      return parse(cached);
    }
    throw OfflineCacheMissException(emptyMessage);
  }
}

Future<T?> fetchOptionalWithCache<T>({
  required OfflineCache cache,
  required String cacheKey,
  required Future<Map<String, dynamic>?> Function() fetchRow,
  required T Function(Map<String, dynamic> json) parse,
}) async {
  try {
    final row = await fetchRow();
    if (row == null) {
      await cache.setJson(cacheKey, {});
      return null;
    }
    await cache.setJson(cacheKey, row);
    return parse(row);
  } catch (error) {
    if (!ApiErrorFormatter.isNetworkError(error)) rethrow;
    final cached = await cache.getJson(cacheKey);
    if (cached == null) rethrow;
    if (cached.isEmpty) return null;
    return parse(cached);
  }
}
