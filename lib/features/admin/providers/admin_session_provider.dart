import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin/admin_session.dart';
import '../../../core/crash/crash_reporter.dart';

class AdminSessionNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final active = await AdminSession.isActive();
    CrashReporter.instance.setAdminMode(active);
    return active;
  }

  Future<void> activate() async {
    await AdminSession.setActive(true);
    CrashReporter.instance.setAdminMode(true);
    state = const AsyncData(true);
  }

  Future<void> deactivate() async {
    await AdminSession.setActive(false);
    CrashReporter.instance.setAdminMode(false);
    state = const AsyncData(false);
  }
}

final adminSessionActiveProvider =
    AsyncNotifierProvider<AdminSessionNotifier, bool>(AdminSessionNotifier.new);
