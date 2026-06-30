import 'dart:io';

/// Restores real network I/O under `flutter test`.
///
/// The widget test binding installs HTTP overrides that return 400. Clearing
/// [HttpOverrides.global] lets `HttpClient` and the Supabase SDK reach local
/// Supabase during integration / E2E tests.
void allowRealHttpInTests() {
  HttpOverrides.global = null;
}
