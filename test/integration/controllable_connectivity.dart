import 'package:tracketiv/core/offline/connectivity_provider.dart';

/// Forces online/offline in integration tests without Flutter platform channels.
class ControllableConnectivity implements OnlineChecker {
  ControllableConnectivity({bool online = true}) : _online = online;

  bool _online;

  bool get online => _online;

  set online(bool value) => _online = value;

  @override
  Future<bool> checkOnline() async => _online;
}
