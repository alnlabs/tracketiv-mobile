import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../reminders/services/notification_service.dart';
import '../../../shared/utils/notification_ids.dart';
import '../data/device_token_repository.dart';

typedef NotificationTapHandler = void Function(Map<String, dynamic> data);

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  DeviceTokenRepository? _repository;
  NotificationTapHandler? onNotificationTap;
  String? _currentToken;
  bool _configured = false;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  bool get isEnabled => _configured;

  Future<bool> configure(SupabaseClient client) async {
    if (kIsWeb || !Env.pushNotificationsEnabled) return false;

    final firebaseReady = await FirebaseBootstrap.initialize();
    if (!firebaseReady) return false;

    _repository = DeviceTokenRepository(client);
    _configured = true;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleTap(initial.data);
    }

    return true;
  }

  Future<void> registerForUser() async {
    if (!_configured || _repository == null) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _saveToken(token);
  }

  Future<void> unregister() async {
    if (!_configured || _repository == null) return;

    final token = _currentToken ?? await _messaging.getToken();
    if (token != null) {
      try {
        await _repository!.removeToken(token);
      } catch (e) {
        debugPrint('Failed to remove device token: $e');
      }
    }

    _currentToken = null;
    await _messaging.deleteToken();
  }

  Future<void> _saveToken(String token) async {
    if (_repository == null) return;
    if (_currentToken == token) return;

    _currentToken = token;
    await _repository!.upsertToken(
      token: token,
      platform: _platformName(),
    );
  }

  Future<void> _onTokenRefresh(String token) async {
    await _saveToken(token);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];
    if (title == null || body == null) return;

    final rawId = message.data['notification_id'];
    final id = rawId is String
        ? NotificationIds.fromKey(rawId)
        : NotificationIds.clamp(DateTime.now().millisecondsSinceEpoch);

    unawaited(
      NotificationService.instance.showInstant(
        id: id,
        title: title,
        body: body,
      ),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _handleTap(message.data);
  }

  void _handleTap(Map<String, dynamic> data) {
    onNotificationTap?.call(Map<String, dynamic>.from(data));
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }
}
