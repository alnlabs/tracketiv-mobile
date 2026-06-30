import 'dart:io';

import '../integration/real_http.dart';

class _E2eHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.idleTimeout = const Duration(milliseconds: 100);
    return client;
  }
}

/// Real HTTP for E2E widget tests with a short idle timeout so connection
/// pool timers do not fail test teardown.
void allowE2eHttpInTests() {
  allowRealHttpInTests();
  HttpOverrides.global = _E2eHttpOverrides();
}
