import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Captures uncaught Flutter/Dart errors and sends them to Supabase.
class CrashReporter {
  CrashReporter._();

  static final CrashReporter instance = CrashReporter._();

  static String appVersion = 'unknown';

  static Future<void> loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      appVersion = 'unknown';
    }
  }

  SupabaseClient? _client;
  bool _adminMode = false;
  String? _currentRoute;
  String? _lastFingerprint;
  DateTime? _lastSentAt;

  void configure(SupabaseClient client) {
    _client = client;
  }

  void setAdminMode(bool active) => _adminMode = active;

  void setCurrentRoute(String? route) => _currentRoute = route;

  void install() {
    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutterOnError?.call(details);
      capture(
        error: details.exception,
        stack: details.stack,
        errorType: 'flutter_framework',
      );
    };

    final previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      capture(error: error, stack: stack, errorType: 'platform');
      return previousPlatformOnError?.call(error, stack) ?? true;
    };
  }

  Future<void> capture({
    required Object error,
    StackTrace? stack,
    String errorType = 'dart',
    Map<String, dynamic>? context,
  }) async {
    if (!Env.isConfigured) return;

    final client = _client;
    if (client == null) return;

    final message = error.toString();
    final fingerprint = '$errorType::$message';
    final now = DateTime.now();
    if (_lastFingerprint == fingerprint &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(seconds: 10)) {
      return;
    }
    _lastFingerprint = fingerprint;
    _lastSentAt = now;

    try {
      await client.rpc('submit_crash_report', params: {
        'p_report': {
          'message': message,
          'stack_trace': stack?.toString(),
          'error_type': errorType,
          'platform': defaultTargetPlatform.name,
          'app_version': appVersion,
          'route': _currentRoute,
          'is_admin_mode': _adminMode,
          'context': context ?? {},
        },
      });
    } catch (e) {
      debugPrint('CrashReporter failed to upload: $e');
    }
  }
}

/// Updates [CrashReporter.currentRoute] from navigation events.
class CrashRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _update(newRoute);
  }

  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    CrashReporter.instance.setCurrentRoute(name);
  }
}
