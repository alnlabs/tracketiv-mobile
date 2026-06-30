class OfflineWriteException implements Exception {
  const OfflineWriteException();

  static const message =
      "You're offline. Connect to the internet to save changes.";
}

class OfflineCacheMissException implements Exception {
  const OfflineCacheMissException(this.message);

  final String message;
}
