import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracketiv/shared/widgets/loading_button.dart';

import '../helpers/pump_app.dart';

void main() {
  setUp(setUpTracketivTests);

  group('LoadingButton', () {
    testWidgets('shows label and responds to tap when idle', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingButton(
              label: 'Save log',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Save log'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('Save log'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows spinner and ignores taps while loading', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingButton(
              label: 'Save log',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save log'), findsNothing);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(tapped, isFalse);
    });
  });
}
