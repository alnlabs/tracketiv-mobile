import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_provider.dart';
import 'offline_cache.dart';
import 'offline_write_exception.dart';

final offlineCacheProvider = Provider<OfflineCache>((ref) => OfflineCache());

extension OfflineGuard on WidgetRef {
  bool get isOnline => read(isOnlineProvider).valueOrNull ?? true;

  Future<bool> requireOnline(
    BuildContext context, {
    String message = OfflineWriteException.message,
  }) async {
    final online = await read(connectivityServiceProvider).checkOnline();
    if (online) return true;
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}
