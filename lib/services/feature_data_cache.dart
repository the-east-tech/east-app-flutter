import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CachedFeatureData {
  final Object? data;
  final DateTime updatedAt;
  final String dayKey;

  const CachedFeatureData({
    required this.data,
    required this.updatedAt,
    required this.dayKey,
  });
}

class FeatureDataCache {
  FeatureDataCache._();

  static final FeatureDataCache instance = FeatureDataCache._();
  static const String _prefix = 'eastapp_feature_cache_v1_';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Map<String, CachedFeatureData> _memory = <String, CachedFeatureData>{};

  String _storageKey(String key) {
    final encoded = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    return '$_prefix$encoded';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  DateTime? updatedAt(String key) => _memory[key]?.updatedAt;

  Future<CachedFeatureData?> read(
    String key, {
    bool invalidateOnNewDay = true,
  }) async {
    final memoryValue = _memory[key];
    if (memoryValue != null) {
      if (!invalidateOnNewDay || memoryValue.dayKey == _todayKey()) {
        return memoryValue;
      }
      await remove(key);
      return null;
    }

    final raw = await _storage.read(key: _storageKey(key));
    if (raw == null || raw.isEmpty) return null;
    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final value = CachedFeatureData(
        data: envelope['data'],
        updatedAt: DateTime.parse(envelope['updatedAt'] as String),
        dayKey: envelope['dayKey'] as String,
      );
      if (invalidateOnNewDay && value.dayKey != _todayKey()) {
        await remove(key);
        return null;
      }
      _memory[key] = value;
      return value;
    } on Object {
      await remove(key);
      return null;
    }
  }

  Future<void> write(String key, Object? data) async {
    final value = CachedFeatureData(
      data: data,
      updatedAt: DateTime.now(),
      dayKey: _todayKey(),
    );
    _memory[key] = value;
    await _storage.write(
      key: _storageKey(key),
      value: jsonEncode({
        'cacheKey': key,
        'updatedAt': value.updatedAt.toIso8601String(),
        'dayKey': value.dayKey,
        'data': data,
      }),
    );
  }

  Future<void> remove(String key) async {
    _memory.remove(key);
    await _storage.delete(key: _storageKey(key));
  }

  Future<void> removeByPrefix(String keyPrefix) async {
    final all = await _storage.readAll();
    final keysToDelete = <String>[];
    for (final entry in all.entries) {
      if (!entry.key.startsWith(_prefix)) continue;
      try {
        final envelope = jsonDecode(entry.value) as Map<String, dynamic>;
        final logicalKey = envelope['cacheKey'] as String?;
        if (logicalKey != null && logicalKey.startsWith(keyPrefix)) {
          keysToDelete.add(entry.key);
        }
      } on Object {
        // Old/corrupt cache entries are removed below only when explicitly read.
      }
    }
    _memory.removeWhere((key, _) => key.startsWith(keyPrefix));
    for (final key in keysToDelete) {
      await _storage.delete(key: key);
    }
  }

  Future<void> clearAll() async {
    _memory.clear();
    final all = await _storage.readAll();
    for (final key in all.keys.where((key) => key.startsWith(_prefix))) {
      await _storage.delete(key: key);
    }
  }
}
