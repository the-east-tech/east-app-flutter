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
    unawaited(_initialiseStorage());
  }

  static final AppDiagnostics instance = AppDiagnostics._();
  static const String _recentErrorsKey = 'eastapp_recent_errors_v2';
  static const String _recentEventsKey = 'eastapp_recent_warnings_v1';
  static const String _legacyRecentErrorsKey = 'eastapp_recent_errors_v1';
  static const String _legacyRecentEventsKeyV1 = 'eastapp_recent_events_v1';
  static const String _legacyRecentEventsKeyV2 = 'eastapp_recent_events_v2';
  static const int _maximumRecentErrors = 5;
  static const int _maximumRecentEvents = 10;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final DateTime _startedAt = DateTime.now();
  final Set<String> _privateValues = <String>{};
  String? _latestDeviceInfo;
  String? _latestCameraInfo;
  final List<_DiagnosticErrorEntry> _recentErrors = <_DiagnosticErrorEntry>[];
  final List<_DiagnosticEventEntry> _recentEvents = <_DiagnosticEventEntry>[];

  Future<void> _initialiseStorage() async {
    try {
      await Future.wait<void>([
        _storage.delete(key: _legacyRecentErrorsKey),
        _storage.delete(key: _legacyRecentEventsKeyV1),
        _storage.delete(key: _legacyRecentEventsKeyV2),
      ]);
    } on Object {
      // Diagnostics must never interrupt normal app startup.
    }
    await Future.wait<void>([
      _loadPersistedErrors(),
      _loadPersistedEvents(),
    ]);
  }

  void registerPrivateEndpoint(String endpoint) {
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) return;
    _privateValues.add(trimmed);
    final uri = Uri.tryParse(trimmed);
    final authority = uri?.authority.trim() ?? '';
    final host = uri?.host.trim() ?? '';
    if (authority.length >= 4) _privateValues.add(authority);
    if (host.length >= 4) _privateValues.add(host);
  }

  String sanitiseForSupport(String value) => _sanitise(value);

  void logWarning(String message) {
    final trimmed = _truncate(_sanitise(message).trim(), 1200);
    if (trimmed.isEmpty) return;
    _recentEvents.insert(
      0,
      _DiagnosticEventEntry(at: DateTime.now(), message: trimmed),
    );
    if (_recentEvents.length > _maximumRecentEvents) {
      _recentEvents.removeRange(_maximumRecentEvents, _recentEvents.length);
    }
    unawaited(_persistEvents());
  }

  void setDeviceInfo(String info) => _latestDeviceInfo = _stamp(info);
  void setCameraInfo(String info) => _latestCameraInfo = _stamp(info);
  String _stamp(String value) =>
      '[${DateTime.now().toIso8601String()}] ${_truncate(_sanitise(value), 1200)}';

  Future<void> _loadPersistedErrors() async {
    try {
      final raw = await _storage.read(key: _recentErrorsKey);
      if (raw == null || raw.isEmpty) return;
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
        ..addAll(merged.take(_maximumRecentErrors));
    } on Object {
      try {
        await _storage.delete(key: _recentErrorsKey);
      } on Object {
        // Ignore unavailable secure storage.
      }
    }
  }

  Future<void> _loadPersistedEvents() async {
    try {
      final raw = await _storage.read(key: _recentEventsKey);
      if (raw == null || raw.isEmpty) return;
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
        ..addAll(merged.take(_maximumRecentEvents));
    } on Object {
      try {
        await _storage.delete(key: _recentEventsKey);
      } on Object {
        // Ignore unavailable secure storage.
      }
    }
  }

  Future<void> _persistEvents() async {
    try {
      await _storage.write(
        key: _recentEventsKey,
        value: jsonEncode(_recentEvents.map((item) => item.toJson()).toList()),
      );
    } on Object {
      // An unavailable diagnostic store must not affect the app.
    }
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
      if (_recentErrors.length > _maximumRecentErrors) {
        _recentErrors.removeRange(_maximumRecentErrors, _recentErrors.length);
      }
    }
    unawaited(_persistErrors());
  }

  Future<void> _persistErrors() async {
    try {
      await _storage.write(
        key: _recentErrorsKey,
        value: jsonEncode(_recentErrors.map((item) => item.toJson()).toList()),
      );
    } on Object {
      // An unavailable diagnostic store must not affect the app.
    }
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
    Object? requestParameters,
  }) {
    final safeRequestTarget = _safeRequestTarget(path);
    final parameterSummary = _summariseRequestParameters(requestParameters);
    final buffer = StringBuffer()
      ..writeln('ApiError')
      ..writeln('Feature: ${_featureFromPath(path)}')
      ..writeln('Action: ${_actionFromRequest(method, path)}')
      ..writeln('Request: ${(method ?? '-').toUpperCase()} $safeRequestTarget');
    if (parameterSummary != null) {
      buffer.writeln('Parameters: $parameterSummary');
    }
    buffer
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
  }) {
    final generatedAt = DateTime.now();
    final reportReference =
        'DBG-${generatedAt.microsecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final buffer = StringBuffer()
      ..writeln("Nic's Kitchen Debug Report")
      ..writeln('Reference: $reportReference')
      ..writeln('Generated: ${generatedAt.toIso8601String()}')
      ..writeln('UTC offset: ${_formatUtcOffset(generatedAt.timeZoneOffset)}')
      ..writeln('Log policy: Errors and warnings only')
      ..writeln('')
      ..writeln('App context')
      ..writeln('- Version: $appVersion')
      ..writeln('- Runtime: $mode')
      ..writeln('- Platform: ${defaultTargetPlatform.name}')
      ..writeln('- OS: ${_platformOsText()}')
      ..writeln('- Uptime: ${_formatDuration(generatedAt.difference(_startedAt))}')
      ..writeln('- Active screen: $activeTab')
      ..writeln('- Language: $language')
      ..writeln('')
      ..writeln('Session context')
      ..writeln('- User: $userName ($userId)')
      ..writeln('- Role: $role')
      ..writeln('- Tenant: $tenantName ($tenantId)')
      ..writeln('')
      ..writeln('Device diagnostics')
      ..writeln('- Device: ${_latestDeviceInfo ?? 'No device detail captured yet'}')
      ..writeln('- Camera: ${_latestCameraInfo ?? 'No camera detail captured yet'}')
      ..writeln('')
      ..writeln(
        'Recent Errors — ${_recentErrors.length}/$_maximumRecentErrors captured',
      );
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
      ..writeln(
        'Recent Warnings — ${_recentEvents.length}/$_maximumRecentEvents captured',
      );
    if (_recentEvents.isEmpty) {
      buffer.writeln('- No warnings captured');
    } else {
      for (var i = 0; i < _recentEvents.length; i++) {
        final item = _recentEvents[i];
        buffer.writeln(
          '${i + 1}. [${item.at.toIso8601String()}] ${item.message}',
        );
      }
    }
    return sanitiseForSupport(buffer.toString().trim());
  }

  String _featureFromPath(String? path) {
    final value = path ?? '';
    if (value.contains('/reports')) return 'Report';
    if (value.contains('/stock')) return 'Stock';
    if (value.contains('/attendance')) return 'Attendance';
    if (value.contains('/tasks')) return 'Task';
    if (value.contains('/notifications')) return 'Notifications';
    if (value.contains('/points')) return 'Points';
    if (value.contains('/tenants')) return 'Business';
    if (value.contains('/setup')) return 'Setup';
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
    if (value.contains('/tasks')) return '$verb Task data';
    if (value.contains('/notifications')) return '$verb Notifications';
    if (value.contains('/points')) return '$verb Points';
    if (value.contains('/tenants')) return '$verb Business data';
    if (value.contains('/setup')) return '$verb Setup';
    if (value.contains('/users')) return '$verb User data';
    if (value.contains('/roles')) return '$verb Role data';
    return '$verb API request';
  }

  String _safeRequestTarget(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final path = uri.path.isEmpty ? '/' : uri.path;
      final target = uri.hasQuery ? '$path?${uri.query}' : path;
      return _sanitise(target);
    }
    return _sanitise(raw);
  }

  String? _summariseRequestParameters(Object? parameters) {
    if (parameters == null) return null;
    try {
      final encoded = jsonEncode(parameters);
      if (encoded == '{}' || encoded == '[]' || encoded == 'null') return null;
      return _truncate(_sanitise(encoded), 1200);
    } on Object {
      final value = _sanitise(parameters.toString()).trim();
      return value.isEmpty ? null : _truncate(value, 1200);
    }
  }

  String _platformOsText() {
    final osVersion = Platform.operatingSystemVersion.replaceAll('\n', ' ').trim();
    return '${Platform.operatingSystem} · ${defaultTargetPlatform.name} · $osVersion';
  }

  String _formatUtcOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (duration.inHours > 0) return '${duration.inHours}h ${minutes}m';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ${seconds}s';
    return '${duration.inSeconds}s';
  }

  List<String> get recentErrors => _recentErrors
      .map((item) => '${item.lastAt.toIso8601String()} · ${item.details}')
      .toList(growable: false);
  List<String> get recentWarnings => _recentEvents
      .map((item) => '[${item.at.toIso8601String()}] ${item.message}')
      .toList(growable: false);

  String _sanitise(String value) {
    var result = value;
    final privateValues = _privateValues.toList(growable: false)
      ..sort((left, right) => right.length.compareTo(left.length));
    for (final privateValue in privateValues) {
      result = result.replaceAll(
        RegExp(RegExp.escape(privateValue), caseSensitive: false),
        '[REDACTED_ENDPOINT]',
      );
    }
    result = result.replaceAll(
      RegExp(
        r'\b(?:[a-z0-9-]+\.)*railway\.(?:app|com)\b',
        caseSensitive: false,
      ),
      '[REDACTED_PROVIDER]',
    );
    result = result.replaceAll(
      RegExp(r'\brailway\b', caseSensitive: false),
      '[REDACTED_PROVIDER]',
    );
    result = result.replaceAll(
      RegExp(
        r'''(?:https?|wss?)://[^\s<>"'\]\[(){}]+''',
        caseSensitive: false,
      ),
      '[REDACTED_URL]',
    );
    result = result.replaceAll(
      RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d{2,5})?\b'),
      '[REDACTED_ADDRESS]',
    );
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
        r'''("?(?:token|sessionToken|accessToken|access_token|refreshToken|refresh_token|password|apiKey|api_key|authorization|cookie|secret|setupCode|setup_code|qrPayload|qr_payload|deviceToken|device_token|pushToken|push_token)"?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^,\s}&]+)''',
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
