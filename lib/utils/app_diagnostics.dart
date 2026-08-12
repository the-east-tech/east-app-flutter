import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _DiagnosticErrorEntry {
  final DateTime firstAt;
  final DateTime lastAt;
  final String details;
  final int occurrences;

  const _DiagnosticErrorEntry({
    required this.firstAt,
    required this.lastAt,
    required this.details,
    required this.occurrences,
  });

  _DiagnosticErrorEntry repeated(DateTime at) => _DiagnosticErrorEntry(
        firstAt: firstAt,
        lastAt: at,
        details: details,
        occurrences: occurrences + 1,
      );

  Map<String, Object?> toJson() => {
        'firstAt': firstAt.toIso8601String(),
        'lastAt': lastAt.toIso8601String(),
        'details': details,
        'occurrences': occurrences,
      };

  factory _DiagnosticErrorEntry.fromJson(Map<String, dynamic> json) {
    return _DiagnosticErrorEntry(
      firstAt: DateTime.parse(json['firstAt'] as String),
      lastAt: DateTime.parse(json['lastAt'] as String),
      details: json['details'] as String,
      occurrences: (json['occurrences'] as num?)?.toInt() ?? 1,
    );
  }
}

class _DiagnosticEventEntry {
  final DateTime at;
  final String message;

  const _DiagnosticEventEntry({required this.at, required this.message});

  Map<String, Object?> toJson() => {
        'at': at.toIso8601String(),
        'message': message,
      };

  factory _DiagnosticEventEntry.fromJson(Map<String, dynamic> json) {
    return _DiagnosticEventEntry(
      at: DateTime.parse(json['at'] as String),
      message: json['message'] as String,
    );
  }
}

class AppDiagnostics {
  AppDiagnostics._() {
    unawaited(_loadPersistedErrors());
    unawaited(_loadPersistedEvents());
  }

  static final AppDiagnostics instance = AppDiagnostics._();
  static const String _recentErrorsKey = 'eastapp_recent_errors_v1';
  static const String _recentEventsKey = 'eastapp_recent_events_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _latestDeviceInfo;
  String? _latestCameraInfo;
  String? _latestMlKitSettings;
  String? _latestFaceScanInfo;
  final List<String> _faceScanTrace = <String>[];
  final List<_DiagnosticErrorEntry> _recentErrors = <_DiagnosticErrorEntry>[];
  final List<_DiagnosticEventEntry> _recentEvents = <_DiagnosticEventEntry>[];

  void log(String message) {
    final trimmed = _truncate(_sanitise(message).trim(), 1200);
    if (trimmed.isEmpty) return;
    _recentEvents.insert(
      0,
      _DiagnosticEventEntry(at: DateTime.now(), message: trimmed),
    );
    if (_recentEvents.length > 10) {
      _recentEvents.removeRange(10, _recentEvents.length);
    }
    unawaited(_persistEvents());
  }

  void setDeviceInfo(String info) => _latestDeviceInfo = _stamp(info);
  void setCameraInfo(String info) => _latestCameraInfo = _stamp(info);
  void setMlKitSettings(String info) => _latestMlKitSettings = _stamp(info);
  void setFaceScanInfo(String info) => _latestFaceScanInfo = _stamp(info);

  void resetFaceScanTrace() {
    _faceScanTrace.clear();
    _latestFaceScanInfo = null;
  }

  void addFaceScanTrace(String info) {
    final stamped = _stamp(info);
    _latestFaceScanInfo = stamped;
    _faceScanTrace.add(stamped);
    if (_faceScanTrace.length > 30) {
      _faceScanTrace.removeRange(0, _faceScanTrace.length - 30);
    }
  }

  String _stamp(String value) =>
      '[${DateTime.now().toIso8601String()}] ${_truncate(_sanitise(value), 1200)}';

  Future<void> _loadPersistedErrors() async {
    final raw = await _storage.read(key: _recentErrorsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      final persisted = values
          .map((item) => _DiagnosticErrorEntry.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(growable: false);
      final merged = <_DiagnosticErrorEntry>[..._recentErrors, ...persisted]
        ..sort((left, right) => right.lastAt.compareTo(left.lastAt));
      _recentErrors
        ..clear()
        ..addAll(merged.take(3));
    } on Object {
      await _storage.delete(key: _recentErrorsKey);
    }
  }

  Future<void> _loadPersistedEvents() async {
    final raw = await _storage.read(key: _recentEventsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      final persisted = values
          .map((item) => _DiagnosticEventEntry.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(growable: false);
      final merged = <_DiagnosticEventEntry>[..._recentEvents, ...persisted]
        ..sort((left, right) => right.at.compareTo(left.at));
      _recentEvents
        ..clear()
        ..addAll(merged.take(10));
    } on Object {
      await _storage.delete(key: _recentEventsKey);
    }
  }

  Future<void> _persistEvents() {
    return _storage.write(
      key: _recentEventsKey,
      value: jsonEncode(_recentEvents.map((item) => item.toJson()).toList()),
    );
  }

  void _recordErrorDetails(String details) {
    final trimmed = _truncate(_sanitise(details).trim(), 4000);
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    if (_recentErrors.isNotEmpty &&
        _recentErrors.first.details == trimmed &&
        now.difference(_recentErrors.first.lastAt) <= const Duration(minutes: 2)) {
      _recentErrors[0] = _recentErrors.first.repeated(now);
    } else {
      _recentErrors.insert(
        0,
        _DiagnosticErrorEntry(
          firstAt: now,
          lastAt: now,
          details: trimmed,
          occurrences: 1,
        ),
      );
      if (_recentErrors.length > 3) {
        _recentErrors.removeRange(3, _recentErrors.length);
      }
    }
    unawaited(_persistErrors());
  }

  Future<void> _persistErrors() {
    return _storage.write(
      key: _recentErrorsKey,
      value: jsonEncode(_recentErrors.map((item) => item.toJson()).toList()),
    );
  }

  void recordApiError({
    required String? method,
    required String? path,
    required int? statusCode,
    required String code,
    required String message,
    required Map<String, String> fieldErrors,
    int? durationMs,
    String? responseExcerpt,
  }) {
    final buffer = StringBuffer()
      ..writeln('ApiError')
      ..writeln('Feature: ${_featureFromPath(path)}')
      ..writeln('Action: ${_actionFromRequest(method, path)}')
      ..writeln('Request: ${method ?? '-'} ${path ?? '-'}')
      ..writeln('Duration: ${durationMs == null ? '-' : '${durationMs}ms'}')
      ..writeln('Status: ${statusCode?.toString() ?? 'No HTTP response'}')
      ..writeln('Code: $code')
      ..writeln('Message: $message');
    if (fieldErrors.isNotEmpty) {
      buffer.writeln('Field errors:');
      fieldErrors.forEach((field, value) => buffer.writeln('- $field: $value'));
    }
    if (responseExcerpt != null && responseExcerpt.trim().isNotEmpty) {
      buffer.writeln('Safe response excerpt: ${_truncate(responseExcerpt.trim(), 1200)}');
    }
    _recordErrorDetails(buffer.toString());
  }

  void recordFlutterError(FlutterErrorDetails details) {
    final buffer = StringBuffer()
      ..writeln('FlutterError')
      ..writeln(details.exceptionAsString());
    final stack = details.stack?.toString().trim();
    if (stack != null && stack.isNotEmpty) buffer.writeln(_trimStack(stack));
    _recordErrorDetails(buffer.toString());
  }

  void recordError(Object error, StackTrace stackTrace) {
    _recordErrorDetails(
      'UnhandledError\n${error.toString()}\n${_trimStack(stackTrace.toString())}',
    );
  }

  String buildReport({
    required String appVersion,
    required String role,
    required String userName,
    required String userId,
    required String activeTab,
    required String language,
    required String mode,
    required String tenantName,
    required String tenantId,
    required String backendBaseUrl,
  }) {
    final buffer = StringBuffer()
      ..writeln("Nic's Kitchen Debug Report")
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('App version: $appVersion')
      ..writeln('Runtime mode: $mode')
      ..writeln('Platform: ${defaultTargetPlatform.name}')
      ..writeln('User: $userName ($userId)')
      ..writeln('Role: $role')
      ..writeln('Active tenant: $tenantName ($tenantId)')
      ..writeln('Active tab: $activeTab')
      ..writeln('Language: $language')
      ..writeln('Backend: $backendBaseUrl')
      ..writeln('')
      ..writeln('Device diagnostics')
      ..writeln('- OS: ${_platformOsText()}')
      ..writeln('- Device: ${_latestDeviceInfo ?? 'No device detail captured yet'}')
      ..writeln('- Camera: ${_latestCameraInfo ?? 'No camera detail captured yet'}')
      ..writeln('- ML Kit settings: ${_latestMlKitSettings ?? 'No ML Kit settings captured yet'}')
      ..writeln('- Face scan: ${_latestFaceScanInfo ?? 'No face scan raw captured yet'}')
      ..writeln('')
      ..writeln('ML Kit raw trace');

    if (_faceScanTrace.isEmpty) {
      buffer.writeln('- None captured in this session');
    } else {
      for (final item in _faceScanTrace) {
        buffer.writeln('- $item');
      }
    }

    buffer
      ..writeln('')
      ..writeln('Recent Errors — latest 3');
    if (_recentErrors.isEmpty) {
      buffer.writeln('- None captured');
    } else {
      for (var i = 0; i < _recentErrors.length; i++) {
        final item = _recentErrors[i];
        buffer
          ..writeln('${i + 1}. ${item.lastAt.toIso8601String()} · occurrences=${item.occurrences}')
          ..writeln(item.details);
      }
    }

    buffer
      ..writeln('')
      ..writeln('Recent Events — latest 10');
    if (_recentEvents.isEmpty) {
      buffer.writeln('- None captured');
    } else {
      for (var i = 0; i < _recentEvents.length; i++) {
        final item = _recentEvents[i];
        buffer.writeln(
          '${i + 1}. [${item.at.toIso8601String()}] ${item.message}',
        );
      }
    }
    return buffer.toString().trim();
  }

  String _featureFromPath(String? path) {
    final value = path ?? '';
    if (value.contains('/reports')) return 'Report';
    if (value.contains('/stock')) return 'Stock';
    if (value.contains('/attendance')) return 'Attendance';
    if (value.contains('/users') || value.contains('/roles')) return 'People';
    if (value.contains('/knowledge')) return 'Knowledge';
    if (value.contains('/auth')) return 'Authentication';
    return 'General';
  }

  String _actionFromRequest(String? method, String? path) {
    final verb = (method ?? 'REQUEST').toUpperCase();
    final value = path ?? '';
    if (value.contains('/reports') && value.contains('/review')) {
      return '$verb report approval';
    }
    if (value.contains('/reports/sales/submit')) {
      return '$verb Sales submission';
    }
    if (value.contains('/reports/sales')) return '$verb Sales report';
    if (value.contains('/reports')) return '$verb Report data';
    if (value.contains('/stock')) return '$verb Stock data';
    if (value.contains('/attendance')) return '$verb Attendance';
    if (value.contains('/users')) return '$verb User data';
    if (value.contains('/roles')) return '$verb Role data';
    return '$verb API request';
  }

  String _platformOsText() {
    final osVersion = Platform.operatingSystemVersion.replaceAll('\n', ' ').trim();
    return '${Platform.operatingSystem} · ${defaultTargetPlatform.name} · $osVersion';
  }

  List<String> get recentErrors => _recentErrors
      .map((item) => '${item.lastAt.toIso8601String()} · ${item.details}')
      .toList(growable: false);
  List<String> get recentEvents => _recentEvents
      .map((item) => '[${item.at.toIso8601String()}] ${item.message}')
      .toList(growable: false);

  String _sanitise(String value) {
    var result = value;
    result = result.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+\-/=]+', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    result = result.replaceAll(
      RegExp(r'AIza[0-9A-Za-z_-]{20,}'),
      '[REDACTED_GOOGLE_API_KEY]',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'("?(?:token|sessionToken|password|apiKey)"?\s*[:=]\s*)[^,\s}]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
    return result;
  }

  String _trimStack(String stack) => stack.split('\n').take(12).join('\n');
  String _truncate(String value, int maxLength) => value.length <= maxLength
      ? value
      : '${value.substring(0, maxLength - 3)}...';
}
