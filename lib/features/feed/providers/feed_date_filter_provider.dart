import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed_date_filter.dart';

const _modeKey = 'feed_date_filter_mode_v1';
const _rangeStartKey = 'feed_date_range_start_v1';
const _rangeEndKey = 'feed_date_range_end_v1';

class FeedDateFilterNotifier extends StateNotifier<FeedDateFilter> {
  FeedDateFilterNotifier() : super(FeedDateFilter.all()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_modeKey);
    if (modeName == null) return;

    FeedDateFilterMode? mode;
    for (final candidate in FeedDateFilterMode.values) {
      if (candidate.name == modeName) {
        mode = candidate;
        break;
      }
    }
    if (mode == null) return;

    switch (mode) {
      case FeedDateFilterMode.today:
        state = FeedDateFilter.today();
      case FeedDateFilterMode.all:
        state = FeedDateFilter.all();
      case FeedDateFilterMode.range:
        final start = _parseDate(prefs.getString(_rangeStartKey));
        final end = _parseDate(prefs.getString(_rangeEndKey));
        if (start != null && end != null) {
          state = FeedDateFilter.range(start: start, end: end);
        } else {
          state = FeedDateFilter.range(
            start: FeedDateFilter.defaultRangeStart(),
            end: FeedDateFilter.dateOnly(DateTime.now()),
          );
        }
    }
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setFilter(FeedDateFilter filter) async {
    state = filter;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, filter.mode.name);
    if (filter.mode == FeedDateFilterMode.range &&
        filter.rangeStart != null &&
        filter.rangeEnd != null) {
      await prefs.setString(
        _rangeStartKey,
        filter.rangeStart!.toIso8601String().split('T').first,
      );
      await prefs.setString(
        _rangeEndKey,
        filter.rangeEnd!.toIso8601String().split('T').first,
      );
    }
  }

  Future<void> resetToDefault() => setFilter(FeedDateFilter.all());
}

final feedDateFilterProvider =
    StateNotifierProvider<FeedDateFilterNotifier, FeedDateFilter>((ref) {
  return FeedDateFilterNotifier();
});
