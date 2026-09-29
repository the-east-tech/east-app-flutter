import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class SkuThumbnailCache {
  SkuThumbnailCache._();

  static final SkuThumbnailCache instance = SkuThumbnailCache._();

  static const int _maximumBytes = 50 * 1024 * 1024;
  static const String _directoryName = 'eastapp_sku_thumbnail_cache_v1';
  static const String _fileExtension = '.thumbnail';

  Directory? _directory;
  Future<Directory>? _directoryRequest;

  Future<Uint8List?> read({
    required String tenantId,
    required String storageKey,
  }) async {
    File? file;
    try {
      file = await _file(tenantId: tenantId, storageKey: storageKey);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        await file.delete();
        return null;
      }
      try {
        await file.setLastModified(DateTime.now());
      } on Object {
        // A last-used timestamp failure must not block a cached thumbnail.
      }
      return bytes;
    } on Object {
      if (file != null) {
        try {
          if (await file.exists()) await file.delete();
        } on Object {
          // A broken cache entry must not block the live thumbnail request.
        }
      }
      return null;
    }
  }

  Future<void> write({
    required String tenantId,
    required String storageKey,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > _maximumBytes) return;
    try {
      final file = await _file(tenantId: tenantId, storageKey: storageKey);
      await file.writeAsBytes(bytes, flush: true);
      await _prune(await _cacheDirectory());
    } on Object {
      // Persistent caching is optional; the downloaded thumbnail remains usable.
    }
  }

  Future<File> _file({
    required String tenantId,
    required String storageKey,
  }) async {
    final logicalKey = '${tenantId.trim()}\u0000${storageKey.trim()}';
    final fileName = '${sha256.convert(utf8.encode(logicalKey))}$_fileExtension';
    final directory = await _cacheDirectory();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<Directory> _cacheDirectory() async {
    final directory = _directory;
    if (directory != null) {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }
    final existing = _directoryRequest;
    if (existing != null) return existing;

    late final Future<Directory> request;
    request = (() async {
      final root = await getApplicationCacheDirectory();
      final value = Directory(
        '${root.path}${Platform.pathSeparator}$_directoryName',
      );
      if (!await value.exists()) {
        await value.create(recursive: true);
      }
      _directory = value;
      return value;
    })().whenComplete(() {
      if (identical(_directoryRequest, request)) {
        _directoryRequest = null;
      }
    });
    _directoryRequest = request;
    return request;
  }

  Future<void> _prune(Directory directory) async {
    final entries = <({File file, int size, DateTime lastUsed})>[];
    var totalBytes = 0;
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith(_fileExtension)) continue;
      try {
        final stat = await entity.stat();
        totalBytes += stat.size;
        entries.add((file: entity, size: stat.size, lastUsed: stat.modified));
      } on Object {
        // Ignore entries that disappear while cache maintenance is running.
      }
    }
    if (totalBytes <= _maximumBytes) return;

    entries.sort((left, right) => left.lastUsed.compareTo(right.lastUsed));
    for (final entry in entries) {
      if (totalBytes <= _maximumBytes) break;
      try {
        await entry.file.delete();
        totalBytes -= entry.size;
      } on Object {
        // A later write will retry cache maintenance.
      }
    }
  }
}
