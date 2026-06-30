enum FeedDateFilterMode { today, range, all }

class FeedDateFilter {
  const FeedDateFilter({
    required this.mode,
    this.rangeStart,
    this.rangeEnd,
  });

  final FeedDateFilterMode mode;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  factory FeedDateFilter.today() =>
      const FeedDateFilter(mode: FeedDateFilterMode.today);

  factory FeedDateFilter.all() => const FeedDateFilter(mode: FeedDateFilterMode.all);

  factory FeedDateFilter.range({
    required DateTime start,
    required DateTime end,
  }) {
    final a = dateOnly(start);
    final b = dateOnly(end);
    return FeedDateFilter(
      mode: FeedDateFilterMode.range,
      rangeStart: a.isBefore(b) ? a : b,
      rangeEnd: a.isBefore(b) ? b : a,
    );
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime defaultRangeStart() {
    final today = dateOnly(DateTime.now());
    return today.subtract(const Duration(days: 6));
  }

  bool get isDefault => mode == FeedDateFilterMode.all;

  bool get countsAsActiveFilter => !isDefault;

  bool matches(DateTime logDate) {
    final day = dateOnly(logDate);
    switch (mode) {
      case FeedDateFilterMode.today:
        return day == dateOnly(DateTime.now());
      case FeedDateFilterMode.all:
        return true;
      case FeedDateFilterMode.range:
        final start = rangeStart;
        final end = rangeEnd;
        if (start == null || end == null) return true;
        return !day.isBefore(start) && !day.isAfter(end);
    }
  }

  String summaryLabel() {
    switch (mode) {
      case FeedDateFilterMode.today:
        return 'Today';
      case FeedDateFilterMode.all:
        return 'All dates';
      case FeedDateFilterMode.range:
        final start = rangeStart;
        final end = rangeEnd;
        if (start == null || end == null) return 'Custom range';
        if (start == end) {
          return _formatDay(start);
        }
        return '${_formatDay(start)} – ${_formatDay(end)}';
    }
  }

  static String _formatDay(DateTime day) =>
      '${day.month}/${day.day}/${day.year}';

  FeedDateFilter copyWith({
    FeedDateFilterMode? mode,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    return FeedDateFilter(
      mode: mode ?? this.mode,
      rangeStart: rangeStart ?? this.rangeStart,
      rangeEnd: rangeEnd ?? this.rangeEnd,
    );
  }
}
