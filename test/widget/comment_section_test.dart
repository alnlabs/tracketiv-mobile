import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracketiv/features/social/providers/social_provider.dart';
import 'package:tracketiv/features/social/widgets/comment_section.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_support.dart';

void main() {
  setUp(setUpTracketivTests);

  group('CommentSection', () {
    late FakeSocialRepository fakeSocial;

    setUp(() {
      fakeSocial = FakeSocialRepository();
    });

    Future<void> pumpComments(
      WidgetTester tester, {
      bool expanded = true,
      List<Override> extraOverrides = const [],
    }) async {
      await pumpTracketivWidget(
        tester,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CommentSection(
              logId: TestFixtures.logId,
              initialExpanded: expanded,
              showExpandToggle: !expanded,
            ),
          ),
        ),
        overrides: [
          socialRepositoryProvider.overrideWithValue(fakeSocial),
          logCommentsProvider.overrideWith(
            (ref, logId) => fakeSocial.getComments(logId),
          ),
          ...extraOverrides,
        ],
      );
    }

    testWidgets('shows linear progress while comments load', (tester) async {
      fakeSocial.commentsDelay = const Duration(milliseconds: 400);

      await pumpComments(tester);
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('No comments yet.'), findsOneWidget);
    });

    testWidgets('shows error when read fails', (tester) async {
      fakeSocial.commentsError = const PostgrestException(
        message: 'Comments unavailable',
        code: '42501',
      );

      await pumpComments(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('permission'), findsOneWidget);
    });

    testWidgets('renders existing comments from API', (tester) async {
      fakeSocial.comments = [
        TestFixtures.comment(body: 'Keep it up!'),
        TestFixtures.comment(id: 'comment-2', body: 'Nice streak'),
      ];

      await pumpComments(tester);
      await tester.pumpAndSettle();

      expect(find.text('Keep it up!'), findsOneWidget);
      expect(find.text('Nice streak'), findsOneWidget);
      expect(find.text('2 comments'), findsNothing);
    });

    testWidgets('expands on toggle and shows comment count', (tester) async {
      fakeSocial.comments = [TestFixtures.comment()];

      await pumpComments(tester, expanded: false);
      await tester.pumpAndSettle();

      expect(find.text('1 comment'), findsOneWidget);
      expect(find.text('Keep it up!'), findsNothing);

      await tapAndSettle(tester, find.text('1 comment'));
      await tester.pumpAndSettle();

      expect(find.text('Great progress!'), findsOneWidget);
    });

    testWidgets('blocks empty submit with snackbar', (tester) async {
      await pumpComments(tester);
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.byIcon(Icons.send));
      await tester.pump();

      expect(find.text('Write a comment before sending.'), findsOneWidget);
      expect(fakeSocial.addedComments, isEmpty);
    });

    testWidgets('creates comment on send tap', (tester) async {
      await pumpComments(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'New comment body');
      await tapAndSettle(tester, find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(fakeSocial.addedComments.single['body'], 'New comment body');
      expect(find.text('New comment body'), findsOneWidget);
    });

    testWidgets('shows send spinner while create is in flight', (tester) async {
      fakeSocial.addCommentDelay = const Duration(milliseconds: 400);

      await pumpComments(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Posting...');
      await tapAndSettle(tester, find.byIcon(Icons.send));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(fakeSocial.addedComments, hasLength(1));
    });

    testWidgets('shows snackbar when create fails', (tester) async {
      fakeSocial.addCommentError = const PostgrestException(
        message: 'Insert failed',
        code: '23505',
      );

      await pumpComments(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Will fail');
      await tapAndSettle(tester, find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not add comment'), findsOneWidget);
    });
  });
}
