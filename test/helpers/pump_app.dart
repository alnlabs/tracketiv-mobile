import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tracketiv/core/theme/app_theme.dart';
import 'package:tracketiv/features/auth/providers/auth_provider.dart';
import 'test_support.dart' show TestFixtures;

/// Prepares the Flutter test binding and disables runtime Google Font fetching.
void setUpTracketivTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Taller viewport so forms with many fields are tappable without scrolling.
void bindLargeTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pumps a widget inside [ProviderScope] + [MaterialApp.router] with GoRouter.
Future<void> pumpTracketivWidget(
  WidgetTester tester, {
  required Widget child,
  List<Override> overrides = const [],
  String initialLocation = '/',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Login screen')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(TestFixtures.testUser()),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
}

/// Standard overrides for an authenticated test user.
Override signedInUser({String? userId}) {
  return currentUserProvider.overrideWithValue(
    TestFixtures.testUser(id: userId ?? TestFixtures.userId),
  );
}

/// Finds a [FilledButton] by its label text.
Finder findButtonByLabel(String label) {
  return find.widgetWithText(FilledButton, label);
}

/// Taps a button and pumps until animations settle.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}
