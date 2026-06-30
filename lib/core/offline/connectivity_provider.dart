import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstraction for online checks (enables integration tests without Flutter plugins).
abstract class OnlineChecker {
  Future<bool> checkOnline();
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

/// Whether the device currently has a network interface (wifi/mobile/etc).
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onlineStream;
});

class ConnectivityService implements OnlineChecker {
  ConnectivityService() {
    _subscription = Connectivity().onConnectivityChanged.listen(_handleChange);
    _refresh();
  }

  /// Test/E2E stub without platform connectivity channels.
  ConnectivityService.test({bool online = true}) : _subscription = null {
    _online = online;
    _controller.add(online);
  }

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _online = true;

  Stream<bool> get onlineStream => _controller.stream;

  bool get isOnline => _online;

  Future<void> _refresh() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _handleChange(results);
    } catch (_) {
      _setOnline(true);
    }
  }

  void _handleChange(List<ConnectivityResult> results) {
    if (kIsWeb) {
      _setOnline(true);
      return;
    }
    final online = results.any((r) => r != ConnectivityResult.none);
    _setOnline(online);
  }

  void _setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    _controller.add(value);
  }

  Future<bool> checkOnline() async {
    await _refresh();
    return _online;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
