import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Avoids [MissingPluginException] when Google Fonts caches files in widget tests.
class E2ePathProvider extends PathProviderPlatform {
  E2ePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => '$root/support';

  @override
  Future<String?> getApplicationDocumentsPath() async => '$root/documents';

  @override
  Future<String?> getTemporaryPath() async => '$root/temp';

  @override
  Future<String?> getLibraryPath() async => '$root/library';

  @override
  Future<String?> getExternalCachePath() async => '$root/external_cache';

  @override
  Future<String?> getExternalStoragePath() async => '$root/external_storage';

  @override
  Future<List<String>?> getExternalCachePaths() async => ['$root/external_cache'];

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) async =>
      ['$root/external_storage'];
}

void installE2ePathProvider(String root) {
  for (final sub in [
    'support',
    'documents',
    'temp',
    'library',
    'external_cache',
    'external_storage',
  ]) {
    Directory('$root/$sub').createSync(recursive: true);
  }
  PathProviderPlatform.instance = E2ePathProvider(root);
}
