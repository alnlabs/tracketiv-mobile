import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_support.dart';

void main() {
  group('FakeProfileRepository upload', () {
    test('uploadAvatar returns public URL and stores bytes', () async {
      final repo = FakeProfileRepository();
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      final url = await repo.uploadAvatar(
        userId: TestFixtures.userId,
        bytes: bytes,
        fileName: 'avatar.jpg',
      );

      expect(url, 'https://cdn.test/avatar.png');
      expect(repo.uploadCallCount, 1);
      expect(repo.lastUploadBytes, bytes);
    });

    test('uploadAvatar propagates errors to callers', () async {
      final repo = FakeProfileRepository(
        uploadError: Exception('Storage upload failed'),
      );

      expect(
        () => repo.uploadAvatar(
          userId: TestFixtures.userId,
          bytes: Uint8List(0),
          fileName: 'avatar.jpg',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('uploadAvatar can simulate slow uploads', () async {
      final repo = FakeProfileRepository(
        uploadDelay: const Duration(milliseconds: 50),
      );

      final stopwatch = Stopwatch()..start();
      await repo.uploadAvatar(
        userId: TestFixtures.userId,
        bytes: Uint8List.fromList([9]),
        fileName: 'a.png',
      );
      stopwatch.stop();

      expect(stopwatch.elapsed.inMilliseconds, greaterThanOrEqualTo(50));
    });
  });
}
