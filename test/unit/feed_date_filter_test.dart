import 'package:flutter_test/flutter_test.dart';
import 'package:tracketiv/features/feed/models/feed_date_filter.dart';

void main() {
  group('FeedDateFilter', () {
    test('today matches only local today by log_date', () {
      final filter = FeedDateFilter.today();
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      expect(filter.matches(today), isTrue);
      expect(filter.matches(yesterday), isFalse);
      expect(filter.isDefault, isTrue);
      expect(filter.countsAsActiveFilter, isFalse);
    });

    test('all matches any log_date', () {
      final filter = FeedDateFilter.all();
      expect(filter.matches(DateTime(2020, 1, 1)), isTrue);
      expect(filter.countsAsActiveFilter, isTrue);
    });

    test('range matches inclusive bounds', () {
      final filter = FeedDateFilter.range(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 7),
      );

      expect(filter.matches(DateTime(2026, 6, 1)), isTrue);
      expect(filter.matches(DateTime(2026, 6, 7)), isTrue);
      expect(filter.matches(DateTime(2026, 5, 31)), isFalse);
      expect(filter.matches(DateTime(2026, 6, 8)), isFalse);
    });
  });
}
