import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracketiv/features/feedback/presentation/feedback_screen.dart';
import 'package:tracketiv/features/feedback/providers/feedback_provider.dart';
import 'package:tracketiv/features/profile/providers/profile_provider.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_support.dart';

Finder feedbackMessageField() => find.byType(TextFormField).last;

void main() {
  setUp(setUpTracketivTests);

  group('FeedbackScreen', () {
    late FakeFeedbackRepository fakeFeedback;

    setUp(() {
      fakeFeedback = FakeFeedbackRepository();
    });

    Future<void> pumpFeedback(WidgetTester tester) async {
      await pumpTracketivWidget(
        tester,
        child: const FeedbackScreen(),
        overrides: [
          feedbackRepositoryProvider.overrideWithValue(fakeFeedback),
          currentProfileProvider.overrideWith(
            (ref) async => TestFixtures.profile(),
          ),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('prefills email from signed-in user', (tester) async {
      await pumpFeedback(tester);

      expect(find.text('runner@tracketiv.test'), findsOneWidget);
    });

    testWidgets('validates message length before submit', (tester) async {
      await pumpFeedback(tester);

      await tester.enterText(feedbackMessageField(), 'short');
      await tapAndSettle(tester, findButtonByLabel('Send feedback'));
      await tester.pump();

      expect(find.text('Please enter at least 10 characters'), findsOneWidget);
      expect(fakeFeedback.submitCallCount, 0);
    });

    testWidgets('submits feedback and shows success snackbar', (tester) async {
      await pumpFeedback(tester);

      await tester.enterText(
        feedbackMessageField(),
        'Please add dark mode to the app',
      );
      await tapAndSettle(tester, findButtonByLabel('Send feedback'));
      await tester.pumpAndSettle();

      expect(fakeFeedback.submitCallCount, 1);
      expect(fakeFeedback.lastMessage, 'Please add dark mode to the app');
      expect(find.text('Thanks! Your feedback was sent.'), findsOneWidget);
    });

    testWidgets('shows loading on button while submit is in flight', (tester) async {
      fakeFeedback.submitDelay = const Duration(milliseconds: 400);

      await pumpFeedback(tester);

      await tester.enterText(
        feedbackMessageField(),
        'Loading state feedback message',
      );
      await tapAndSettle(tester, findButtonByLabel('Send feedback'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(fakeFeedback.submitCallCount, 1);
    });

    testWidgets('shows error snackbar when submit fails', (tester) async {
      fakeFeedback.submitError = const PostgrestException(
        message: 'RPC failed',
        code: '500',
      );

      await pumpFeedback(tester);

      await tester.enterText(
        feedbackMessageField(),
        'This submit should fail badly',
      );
      await tapAndSettle(tester, findButtonByLabel('Send feedback'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not send feedback'), findsOneWidget);
      expect(fakeFeedback.submitCallCount, 1);
    });
  });
}
