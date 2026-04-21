import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:offlinepay_api/offlinepay_api.dart';

typedef NotificationTapHandler = void Function(Map<String, String> data);
typedef NotificationForegroundHandler = void Function(Map<String, String> data);

@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  developer.log(
    'background fcm received: type=${message.data['type']}',
    name: 'push',
  );
}

class PushNotificationsService {
  PushNotificationsService({
    required DefaultApi api,
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
  })  : _api = api,
        _scaffoldMessengerKey = scaffoldMessengerKey;

  final DefaultApi _api;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  String? _lastRegisteredToken;
  NotificationTapHandler? _onNotificationTap;
  NotificationForegroundHandler? _onForegroundMessage;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  bool _initialMessageHandled = false;

  Future<void> init({
    NotificationTapHandler? onNotificationTap,
    NotificationForegroundHandler? onForegroundMessage,
  }) async {
    _onNotificationTap = onNotificationTap;
    _onForegroundMessage = onForegroundMessage;
    _foregroundSub ??= FirebaseMessaging.onMessage.listen(_handleForeground);
    _openedAppSub ??=
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedApp);
  }

  Future<void> registerForUser({required String accessToken}) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        developer.log('push permission denied', name: 'push');
        return;
      }

      if (!kIsWeb && Platform.isIOS) {
        await _messaging.getAPNSToken();
      }
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        developer.log('fcm token null', name: 'push');
        return;
      }
      await _postToken(token: token, accessToken: accessToken);
      _lastRegisteredToken = token;

      _tokenRefreshSub ??= _messaging.onTokenRefresh.listen((newToken) {
        unawaited(
          _postToken(token: newToken, accessToken: accessToken).then(
            (_) => _lastRegisteredToken = newToken,
            onError: (Object e, StackTrace st) {
              developer.log('fcm refresh register failed',
                  error: e, stackTrace: st, name: 'push');
            },
          ),
        );
      });
    } catch (e, st) {
      developer.log('push register failed',
          error: e, stackTrace: st, name: 'push');
    }
  }

  Future<void> unregister({required String accessToken}) async {
    final token = _lastRegisteredToken ?? await _safeGetToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _api.deleteV1DevicesPushToken(
          pushTokenDeleteBody:
              PushTokenDeleteBody((b) => b..fcmToken = token),
          headers: _bearer(accessToken),
        );
      } catch (e, st) {
        developer.log('push unregister failed',
            error: e, stackTrace: st, name: 'push');
      }
    }
    try {
      await _messaging.deleteToken();
    } catch (_) {}
    _lastRegisteredToken = null;
  }

  Future<void> handleInitialMessageIfAny() async {
    if (_initialMessageHandled) return;
    _initialMessageHandled = true;
    try {
      final msg = await _messaging.getInitialMessage();
      if (msg != null) {
        _dispatchTap(msg.data);
      }
    } catch (_) {}
  }

  Future<void> _postToken({
    required String token,
    required String accessToken,
  }) async {
    final platform = _platformEnum();
    if (platform == null) return;
    await _api.postV1DevicesPushToken(
      pushTokenBody: PushTokenBody((b) => b
        ..fcmToken = token
        ..platform = platform),
      headers: _bearer(accessToken),
    );
  }

  Future<String?> _safeGetToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  void _handleForeground(RemoteMessage message) {
    final notification = message.notification;
    final title =
        (notification?.title ?? message.data['title']?.toString() ?? 'Notification');
    final body = (notification?.body ?? message.data['body']?.toString() ?? '');
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(body.isEmpty ? title : '$title — $body'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    final handler = _onForegroundMessage;
    if (handler != null) {
      final data = <String, String>{};
      message.data.forEach((key, value) {
        if (value != null) data[key] = value.toString();
      });
      handler(data);
    }
  }

  void _handleOpenedApp(RemoteMessage message) {
    _dispatchTap(message.data);
  }

  void _dispatchTap(Map<String, dynamic> rawData) {
    if (_onNotificationTap == null) return;
    final data = <String, String>{};
    rawData.forEach((key, value) {
      if (value != null) data[key] = value.toString();
    });
    _onNotificationTap!(data);
  }

  Map<String, dynamic> _bearer(String token) =>
      <String, dynamic>{'Authorization': 'Bearer $token'};

  static PushTokenBodyPlatformEnum? _platformEnum() {
    try {
      if (Platform.isAndroid) return PushTokenBodyPlatformEnum.android;
      if (Platform.isIOS) return PushTokenBodyPlatformEnum.ios;
    } catch (_) {}
    return null;
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    await _tokenRefreshSub?.cancel();
  }
}
