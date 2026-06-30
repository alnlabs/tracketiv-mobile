import 'package:flutter_test/flutter_test.dart';
import 'package:tracketiv/shared/utils/validators.dart';

void main() {
  group('Validators', () {
    test('require email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('bad'), isNotNull);
      expect(Validators.email('user@example.com'), isNull);
    });
  });
}
