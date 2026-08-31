import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../utils/app_diagnostics.dart';
import 'east_app_api.dart';

@pragma('vm:entry-point')
Future<void> eastAppFirebaseBackgroundHandler(RemoteMessage message) async {
  final options = PushNotificationService.currentPlatformOptions;
  if (options == null || Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: options);
}

class PushNotificationService {
  static bool _backgroundHandlerRegistered = false;

  EastAppApi? _api;
  String? _token;
  bool _firebaseInitialised = false;
  bool _initialMessageHandled = false;
  Future<void>? _configureRequest;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  void Function(String? notificationId)? _onReceived;
  void Function(String? notificationId)? _onOpened;

  static FirebaseOptions? get currentPlatformOptions =>
      EastAppFirebaseOptions.currentPlatform;

  static void registerBackgroundHandler() {
    if (_backgroundHandlerRegistered) return;
    FirebaseMessaging.onBackgroundMessage(eastAppFirebaseBackgroundHandler);
    _backgroundHandlerRegistered = true;
  }

  Future<void> configure({
    required EastAppApi api,
    required void Function(String? notificationId) onReceived,
    required void Function(String? notificationId) onOpened,
  }) {
    _api = api;
    _onReceived = onReceived;
    _onOpened = onOpened;
    final existing = _configureRequest;
    if (existing != null) return existing;

    late final Future<void> request;
    request = _configure().whenComplete(() {
      if (identical(_configureRequest, request)) _configureRequest = null;
    });
    _configureRequest = request;
    return request;
  }

  Future<void> _configure() async {
    final options = currentPlatformOptions;
    if (options == null) {
      AppDiagnostics.instance.log(
        'Native push is not configured; the in-app notification inbox remains active.',
      );
      return;
    }

    try {
      if (!_firebaseInitialised) {
        registerBackgroundHandler();
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: options);
        }
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        _listen();
        _firebaseInitialised = true;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _waitForApnsToken();
      }
      _token = await FirebaseMessaging.instance.getToken();
      await _registerCurrentToken();

      if (!_initialMessageHandled) {
        _initialMessageHandled = true;
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) _onOpened?.call(_notificationId(initial));
      }
    } catch (error) {
      AppDiagnostics.instance.log('Native push setup is unavailable: $error');
    }
  }

  void _listen() {
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) {
        _token = token;
        unawaited(_registerCurrentToken());
      },
    );
    _messageSubscription = FirebaseMessaging.onMessage.listen(
      (message) => _onReceived?.call(_notificationId(message)),
    );
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _onOpened?.call(_notificationId(message)),
    );
  }

  Future<void> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await FirebaseMessaging.instance.getAPNSToken() != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    throw StateError('APNs token was not available after notification setup.');
  }

  Future<void> _registerCurrentToken() async {
    final api = _api;
    final token = _token;
    if (api == null || token == null || token.isEmpty) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'IOS'
        : 'ANDROID';
    try {
      await api.registerPushDevice(token: token, platform: platform);
    } on EastAppApiException catch (error) {
      AppDiagnostics.instance.log(
        'Push token registration failed: ${error.code} ${error.message}',
      );
    }
  }

  Future<void> unregister() async {
    final api = _api;
    final token = _token;
    if (api == null || token == null || token.isEmpty) return;
    try {
      await api.unregisterPushDevice(token);
    } on EastAppApiException catch (error) {
      AppDiagnostics.instance.log(
        'Push token unregister failed: ${error.code} ${error.message}',
      );
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
  }

  static String? _notificationId(RemoteMessage message) {
    final value = message.data['notificationId'];
    return value == null || value.trim().isEmpty ? null : value.trim();
  }
}
