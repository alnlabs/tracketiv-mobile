import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/offline/offline_provider.dart';
import '../../connections/providers/connections_provider.dart';
import '../data/feed_repository.dart';
import '../providers/feed_date_filter_provider.dart';
import '../../../shared/models/feed_item.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(offlineCacheProvider),
  );
});

enum FeedFilterOption { groups, me, friends }

extension FeedFilterOptionX on FeedFilterOption {
  String get label {
    switch (this) {
      case FeedFilterOption.groups:
        return 'Groups';
      case FeedFilterOption.me:
        return 'My updates';
      case FeedFilterOption.friends:
        return 'Friends';
    }
  }
}

final feedFiltersProvider = StateProvider<Set<FeedFilterOption>>((ref) => {});

/// Raw feed from network/cache — not filtered by date or chips.
final feedProvider = AsyncNotifierProvider<FeedNotifier, List<FeedItem>>(FeedNotifier.new);

/// Feed rows after date + chip filters (does not re-fetch from network).
final displayedFeedProvider = Provider<List<FeedItem>>((ref) {
  final raw = ref.watch(feedProvider).valueOrNull ?? const <FeedItem>[];
  return applyFeedDisplayFilters(ref, raw);
});

final feedPostProvider = FutureProvider.family<FeedItem?, String>((ref, logId) async {
  final feedItems = ref.watch(displayedFeedProvider);
  for (final item in feedItems) {
    if (item.logId == logId) return item;
  }
  final raw = ref.watch(feedProvider).valueOrNull ?? const <FeedItem>[];
  for (final item in raw) {
    if (item.logId == logId) return item;
  }
  return ref.watch(feedRepositoryProvider).getFeedPost(logId);
});

class FeedNotifier extends AsyncNotifier<List<FeedItem>> {
  static const _cacheKey = 'feed_50';

  @override
  Future<List<FeedItem>> build() async {
    ref.watch(currentUserProvider);

    final cache = ref.read(offlineCacheProvider);
    final cachedRows = await cache.getJsonList(_cacheKey);
    if (cachedRows != null && cachedRows.isNotEmpty) {
      final cached = _parseFeedRows(cachedRows);
      Future.microtask(_refreshFromNetwork);
      return cached;
    }

    return _fetchFromNetwork();
  }

  Future<void> _refreshFromNetwork() async {
    try {
      final fresh = await _fetchFromNetwork();
      state = AsyncData(fresh);
    } catch (error, stackTrace) {
      if (state.hasValue) return;
      state = AsyncError(error, stackTrace);
    }
  }

  Future<List<FeedItem>> _fetchFromNetwork() async {
    final raw = await ref.read(feedRepositoryProvider).getFeed();
    return _enrichPreviousLogValues(raw);
  }

  List<FeedItem> _parseFeedRows(List<Map<String, dynamic>> rows) {
    final items = <FeedItem>[];
    for (final row in rows) {
      try {
        items.add(FeedItem.fromJson(row));
      } catch (_) {
        // Skip corrupt cache rows instead of failing the whole feed.
      }
    }
    return _enrichPreviousLogValues(items);
  }
}

List<FeedItem> applyFeedDisplayFilters(Ref ref, List<FeedItem> items) {
  final user = ref.watch(currentUserProvider);
  final filters = ref.watch(feedFiltersProvider);
  final dateFilter = ref.watch(feedDateFilterProvider);
  final friendIds = ref.watch(myFriendsProvider).valueOrNull
          ?.map((f) => f.friendId)
          .toSet() ??
      const <String>{};

  var filtered = items.where((item) {
    if (item.isWidget) return true;
    return dateFilter.matches(item.logDate);
  });

  if (filters.isEmpty) return filtered.toList();

  return filtered.where((item) {
    if (item.isWidget) {
      if (filters.contains(FeedFilterOption.groups) && item.groupId != null) {
        return true;
      }
      if (filters.contains(FeedFilterOption.me) &&
          user != null &&
          item.widgetUserId == user.id) {
        return true;
      }
      return false;
    }

    if (filters.contains(FeedFilterOption.friends) &&
        user != null &&
        item.authorId != null &&
        item.authorId != user.id &&
        friendIds.contains(item.authorId)) {
      return true;
    }

    if (filters.contains(FeedFilterOption.groups) && item.isGroup) return true;
    if (filters.contains(FeedFilterOption.me) &&
        user != null &&
        item.authorId == user.id) {
      return true;
    }
    return false;
  }).toList();
}

List<FeedItem> _enrichPreviousLogValues(List<FeedItem> items) {
  return List.generate(items.length, (index) {
    final item = items[index];
    if (item.isWidget || item.logValue == null || item.previousLogValue != null) {
      return item;
    }

    for (var olderIndex = index + 1; olderIndex < items.length; olderIndex++) {
      final older = items[olderIndex];
      if (older.isWidget) continue;
      if (older.authorId == item.authorId &&
          older.goalId == item.goalId &&
          older.logValue != null) {
        return item.copyWith(previousLogValue: older.logValue);
      }
    }
    return item;
  });
}
