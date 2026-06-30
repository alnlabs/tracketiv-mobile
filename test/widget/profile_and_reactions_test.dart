import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracketiv/features/profile/presentation/profile_screen.dart';
import 'package:tracketiv/features/profile/providers/profile_provider.dart';
import 'package:tracketiv/features/social/providers/social_provider.dart';
import 'package:tracketiv/features/social/widgets/log_reaction_bar.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_support.dart';

void main() {
  setUp(setUpTracketivTests);

  group('ProfileScreen', () {
    late FakeProfileRepository fakeProfile;

    setUp(() {
      fakeProfile = FakeProfileRepository(profile: TestFixtures.profile());
    });

    Future<void> pumpProfile(
      WidgetTester tester, {
      List<Override> extraOverrides = const [],
    }) async {
      await pumpTracketivWidget(
        tester,
        child: const ProfileScreen(),
        overrides: [
          profileRepositoryProvider.overrideWithValue(fakeProfile),
          currentProfileProvider.overrideWith(
            (ref) => fakeProfile.getProfile(TestFixtures.userId),
          ),
          userProfileStatsProvider.overrideWith(
            (ref, userId) async => TestFixtures.profileStats(),
          ),
          ...extraOverrides,
        ],
      );
    }

    testWidgets('shows loading spinner while profile loads', (tester) async {
      fakeProfile.profileDelay = const Duration(milliseconds: 400);

      await pumpTracketivWidget(
        tester,
        child: const ProfileScreen(),
        overrides: [
          profileRepositoryProvider.overrideWithValue(fakeProfile),
          currentProfileProvider.overrideWith(
            (ref) => fakeProfile.getProfile(TestFixtures.userId),
          ),
          userProfileStatsProvider.overrideWith(
            (ref, userId) async => TestFixtures.profileStats(),
          ),
        ],
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Test Runner'), findsOneWidget);
    });

    testWidgets('shows error when profile read fails', (tester) async {
      await pumpTracketivWidget(
        tester,
        child: const ProfileScreen(),
        overrides: [
          profileRepositoryProvider.overrideWithValue(fakeProfile),
          currentProfileProvider.overrideWith(
            (ref) => Future.error(
              const PostgrestException(message: 'Profile read failed', code: '500'),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile read failed'), findsOneWidget);
    });

    testWidgets('displays profile data after read', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(find.text('Test Runner'), findsOneWidget);
      expect(find.text('@testrunner'), findsWidgets);
      expect(find.text('runner@tracketiv.test'), findsOneWidget);
    });

    testWidgets('enters edit mode on edit button tap', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        findButtonByLabel('Save'),
        120,
        scrollable: find.byType(Scrollable).first,
      );

      expect(findButtonByLabel('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('saves profile on save tap', (tester) async {
      bindLargeTestViewport(tester);
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'Updated Name');
      await tapAndSettle(tester, findButtonByLabel('Save'));
      await tester.pumpAndSettle();

      expect(fakeProfile.updateCallCount, 1);
      expect(fakeProfile.lastUpdate?.displayName, 'Updated Name');
    });

    testWidgets('shows error snackbar when save fails', (tester) async {
      bindLargeTestViewport(tester);
      fakeProfile.updateError = const AuthException('Username is already taken');

      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tapAndSettle(tester, findButtonByLabel('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Username is already taken'), findsOneWidget);
    });
  });

  group('LogReactionBar', () {
    late FakeSocialRepository fakeSocial;

    setUp(() {
      fakeSocial = FakeSocialRepository(
        reactionSummaries: TestFixtures.reactionSummaries(reactedByMe: true),
      );
    });

    Future<void> pumpReactionBar(WidgetTester tester) async {
      await pumpTracketivWidget(
        tester,
        child: const Scaffold(
          body: LogReactionBar(logId: TestFixtures.logId),
        ),
        overrides: [
          socialRepositoryProvider.overrideWithValue(fakeSocial),
          logReactionsProvider.overrideWith(
            (ref, logId) => fakeSocial.getReactionSummaries(
              logId,
              TestFixtures.userId,
            ),
          ),
        ],
      );
    }

    testWidgets('shows loading indicator while reactions load', (tester) async {
      fakeSocial.reactionsDelay = const Duration(milliseconds: 400);

      await pumpReactionBar(tester);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('toggles reaction (delete) when chip is tapped', (tester) async {
      await pumpReactionBar(tester);
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.text('🔥'));
      await tester.pumpAndSettle();

      expect(fakeSocial.toggledReactions, hasLength(1));
      expect(fakeSocial.toggledReactions.single['emojiType'], 'fire');
    });
  });
}
