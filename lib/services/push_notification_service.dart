import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../firebase_options.dart';
import '../utils/app_build_info.dart';
import '../utils/app_diagnostics.dart';
import 'flow_api.dart';

@pragma('vm:entry-point')
Future<void> flowFirebaseBackgroundHandler(RemoteMessage message) async {
  final options = PushNotificationService.currentPlatformOptions;
  if (options == null || Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: options);
}

class PushNotificationService {
  static bool _backgroundHandlerRegistered = false;
  static const _firebaseIdentityStorageKey =
      'flow.push.firebase.configuration';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  FlowApi? _api;
  String? _token;
  String? _configuredFirebaseIdentity;
  bool _firebaseInitialised = false;
  bool _initialMessageHandled = false;
  Future<void>? _configureRequest;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  void Function(String? notificationId)? _onReceived;
  void Function(String? notificationId)? _onOpened;

  static FirebaseOptions? get currentPlatformOptions =>
      FlowFirebaseOptions.currentPlatform;

  static void registerBackgroundHandler() {
    if (_backgroundHandlerRegistered) return;
    FirebaseMessaging.onBackgroundMessage(flowFirebaseBackgroundHandler);
    _backgroundHandlerRegistered = true;
  }

  Future<void> configure({
    required FlowApi api,
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
      AppDiagnostics.instance.logWarning(
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
      await _resetTokenAfterFirebaseMigration(options);
      _token = await FirebaseMessaging.instance.getToken();
      await _rememberFirebaseIdentity(options);
      await _registerCurrentToken();

      if (!_initialMessageHandled) {
        _initialMessageHandled = true;
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) _onOpened?.call(_notificationId(initial));
      }
    } catch (error) {
      AppDiagnostics.instance.logWarning(
        error.toString().contains('APNs token')
            ? 'iOS push notifications are unavailable because APNs did not provide a device token. The in-app notification inbox remains active.'
            : 'Native push setup is unavailable: $error',
      );
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

  Future<void> _resetTokenAfterFirebaseMigration(
    FirebaseOptions options,
  ) async {
    final identity = _firebaseIdentity(options);
    if (_configuredFirebaseIdentity == identity) return;

    String? storedIdentity;
    try {
      storedIdentity = await _storage.read(key: _firebaseIdentityStorageKey);
    } catch (error) {
      AppDiagnostics.instance.logWarning(
        'Unable to read the saved Firebase push configuration: $error',
      );
      _configuredFirebaseIdentity = identity;
      return;
    }

    if (storedIdentity != identity) {
      await FirebaseMessaging.instance.deleteToken();
    }
    _configuredFirebaseIdentity = identity;
  }

  Future<void> _rememberFirebaseIdentity(FirebaseOptions options) async {
    if (_token == null || _token!.isEmpty) return;
    try {
      await _storage.write(
        key: _firebaseIdentityStorageKey,
        value: _firebaseIdentity(options),
      );
    } catch (error) {
      AppDiagnostics.instance.logWarning(
        'Unable to save the Firebase push configuration: $error',
      );
    }
  }

  String _firebaseIdentity(FirebaseOptions options) =>
      '${options.projectId}:${options.messagingSenderId}:${options.appId}';

  Future<void> _registerCurrentToken() async {
    final api = _api;
    final token = _token;
    if (api == null || token == null || token.isEmpty) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'IOS'
        : 'ANDROID';
    final appVersion = AppBuildInfo.displayVersion;
    try {
      await api.registerPushDevice(
        token: token,
        platform: platform,
        appVersion: appVersion,
      );
    } on FlowApiException catch (error) {
      AppDiagnostics.instance.recordApiError(
        method: error.method ?? 'POST',
        path: error.path ?? '/api/v1/notifications/devices',
        statusCode: error.statusCode,
        code: error.code,
        message: error.message,
        fieldErrors: error.fieldErrors,
        durationMs: error.durationMs,
        responseExcerpt: error.responseExcerpt,
        requestParameters: {
          'token': token,
          'platform': platform,
          'appVersion': appVersion,
        },
      );
    }
  }

  Future<void> unregister() async {
    final api = _api;
    final token = _token;
    if (api == null || token == null || token.isEmpty) return;
    try {
      await api.unregisterPushDevice(token);
    } on FlowApiException catch (error) {
      AppDiagnostics.instance.recordApiError(
        method: error.method ?? 'POST',
        path: error.path ?? '/api/v1/notifications/devices/unregister',
        statusCode: error.statusCode,
        code: error.code,
        message: error.message,
        fieldErrors: error.fieldErrors,
        durationMs: error.durationMs,
        responseExcerpt: error.responseExcerpt,
        requestParameters: {'token': token},
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
