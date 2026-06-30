import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration/real_http.dart';
import 'e2e_bootstrap.dart';
import 'e2e_screen_catalog.dart';

void main() {
  allowRealHttpInTests();

  late bool localSupabaseUp;

  setUpAll(() async {
    localSupabaseUp = await E2eBootstrap.isLocalStackRunning();
  });

  for (final role in E2eRole.values) {
    testWidgets('E2E: $role visits every screen', (tester) async {
      if (!localSupabaseUp) {
        fail(
          'Local Supabase is not running. '
          'Run: supabase start && supabase db reset '
          'or ./scripts/test-supabase.sh',
        );
      }

      final isAdmin = role == E2eRole.admin;

      await E2eBootstrap.launchApp(
        tester,
        E2eLaunchOptions(
          role: role,
          adminConsoleActive: isAdmin,
        ),
      );

      for (final screen in e2eScreenCatalog) {
        final expectation = screen.forRole(role);
        if (expectation == null) continue;

        await E2eBootstrap.visitScreen(tester, screen);
        E2eBootstrap.assertExpectation(tester, expectation);
      }

      await E2eBootstrap.tearDownApp(tester);
    });
  }

  testWidgets('E2E: guest with fresh onboarding sees onboarding first', (tester) async {
    if (!localSupabaseUp) {
      fail(
        'Local Supabase is not running. '
        'Run: supabase start && supabase db reset '
        'or ./scripts/test-supabase.sh',
      );
    }

    await E2eBootstrap.launchApp(
      tester,
      const E2eLaunchOptions(
        role: E2eRole.guest,
        onboardingCompleted: false,
      ),
    );

    expect(find.text('Set goals that matter'), findsWidgets);

    await E2eBootstrap.visitScreen(
      tester,
      e2eScreenCatalog.firstWhere((s) => s.id == 'home_feed'),
    );
    E2eBootstrap.assertExpectation(
      tester,
      const E2eRedirect('/onboarding'),
    );

    await E2eBootstrap.tearDownApp(tester);
  });
}
