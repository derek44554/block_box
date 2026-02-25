import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../blocks/file/models/file_card_data.dart';
import '../../../utils/ipfs_file_helper.dart';

enum ImageVariant {
  small,
  medium,
  original,
}

extension ImageVariantExt on ImageVariant {
  String get suffix {
    switch (this) {
      case ImageVariant.small:
        return 'sm';
      case ImageVariant.medium:
        return 'md';
      case ImageVariant.original:
        return '';
    }
  }

  int? get targetWidth {
    switch (this) {
      case ImageVariant.small:
        return 240;
      case ImageVariant.medium:
        return 480;
      case ImageVariant.original:
        return null;
    }
  }

  int get priority {
    switch (this) {
      case ImageVariant.small:
        return 0;
      case ImageVariant.medium:
        return 1;
      case ImageVariant.original:
        return 2;
    }
  }
}

class ImageCacheHelper {
  ImageCacheHelper._();

  static const int maxCacheSizeBytes = 2 * 1024 * 1024 * 1024; // 2 GiB
  static const int maxMemoryCacheEntries = 200;
  static const int maxMemoryCacheBytes = 120 * 1024 * 1024; // 120 MiB
  static const int _bucketCount = 2;
  static const int _bucketSegmentLength = 2;

  static final _InMemoryCache _memoryCache = _InMemoryCache(
    maxEntries: maxMemoryCacheEntries,
    maxBytes: maxMemoryCacheBytes,
  );
  static final Map<String, Future<Uint8List>> _variantGenerationTasks = <String, Future<Uint8List>>{};

  static Future<String> _getCacheDirectoryPath() async {
    final dir = await getApplicationSupportDirectory();
    final cachePath = p.join(dir.path, 'image_cache');
    final cacheDir = Directory(cachePath);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cachePath;
  }

  static String _sanitizeCid(String cid) {
    final trimmed = cid.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'[^0-9a-zA-Z._-]'), '_');
  }

  static String _buildRelativePath(String cid) {
    final sanitized = _sanitizeCid(cid);
    if (sanitized.isEmpty) {
      return sanitized;
    }

    final segments = <String>[];
    for (var i = 0; i < _bucketCount; i++) {
      final start = i * _bucketSegmentLength;
      if (start >= sanitized.length) {
        break;
      }
      final end = min(start + _bucketSegmentLength, sanitized.length);
      segments.add(sanitized.substring(start, end));
    }

    segments.add(sanitized);
    return p.joinAll(segments);
  }

  static Future<File> _resolveCacheFile(String cid, {required bool createDirectories}) async {
    final cacheRoot = await _getCacheDirectoryPath();
    final relativePath = _buildRelativePath(cid);
    final filePath = p.join(cacheRoot, relativePath);
    if (createDirectories) {
      final directory = Directory(p.dirname(filePath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
    return File(filePath);
  }

  static Future<void> _updateAccessTime(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } catch (error, stackTrace) {
      // Failed to update access time
    }
  }

  static Future<File?> getCachedImage(
    String cid, {
    ImageVariant variant = ImageVariant.original,
  }) async {
    if (cid.isEmpty) return null;
    try {
      final key = _composeKey(cid, variant);
      final file = await _resolveCacheFile(key, createDirectories: false);
      if (await file.exists()) {
        await _updateAccessTime(file);
        return file;
      }
    } catch (error, stackTrace) {
      // Failed to read cache
    }
    return null;
  }

  static Future<void> saveImageToCache(String cid, Uint8List bytes,
      {ImageVariant variant = ImageVariant.original}) async {
    if (cid.isEmpty) return;
    try {
      cacheMemoryImage(cid, bytes, variant: variant);
      final key = _composeKey(cid, variant);
      final file = await _resolveCacheFile(key, createDirectories: true);
      await file.writeAsBytes(bytes, flush: true);
      await _updateAccessTime(file);
      _scheduleCleanup();
    } catch (error, stackTrace) {
      // Failed to write cache
    }
  }

  static Uint8List? getMemoryImage(
    String cid, {
    ImageVariant variant = ImageVariant.original,
  }) {
    if (cid.isEmpty) return null;
    return _memoryCache.get(_composeKey(cid, variant));
  }

  static void cacheMemoryImage(
    String cid,
    Uint8List bytes, {
    ImageVariant variant = ImageVariant.original,
  }) {
    if (cid.isEmpty) return;
    _memoryCache.put(_composeKey(cid, variant), bytes);
  }

  static Future<Uint8List> getOrLoadImage({
    required String cid,
    required FileCardData data,
    String? endpoint,
    ImageVariant variant = ImageVariant.original,
  }) async {
    final memoryBytes = getMemoryImage(cid, variant: variant);
    if (memoryBytes != null) {
      return memoryBytes;
    }

    final cachedFile = await getCachedImage(cid, variant: variant);
    if (cachedFile != null) {
      final bytes = await cachedFile.readAsBytes();
      unawaited(warmUpMemoryCache(cid, bytes, variant: variant));
      return bytes;
    }

    if (endpoint == null || endpoint.isEmpty) {
      throw Exception('IPFS endpoint is not set');
    }

    return IpfsFileHelper.loadByCid(
      endpoint: endpoint,
      data: data,
      variant: variant,
    );
  }

  static Future<void> removeFromCache(String cid) async {
    if (cid.isEmpty) return;
    for (final variant in ImageVariant.values) {
      final key = _composeKey(cid, variant);
      _memoryCache.remove(key);
      try {
        final file = await _resolveCacheFile(key, createDirectories: false);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error, stackTrace) {
        // Failed to delete cache
      }
    }
  }

  static final Set<String> _warming = <String>{};

  static Future<void> warmUpMemoryCache(String cid, Uint8List bytes,
      {ImageVariant variant = ImageVariant.original}) async {
    if (cid.isEmpty) return;
    // 仅存入内存缓存，不进行主动解码，避免占用 UI 线程资源。
    // 解码将由 UI 组件在渲染时按需触发。
    cacheMemoryImage(cid, bytes, variant: variant);
  }

  static Future<void>? _cleanupTask;

  static void _scheduleCleanup() {
    if (_cleanupTask != null) {
      return;
    }
    _cleanupTask = Future.microtask(() async {
      try {
        await _enforceCacheLimit();
      } finally {
        _cleanupTask = null;
      }
    });
  }

  static Future<void> _enforceCacheLimit() async {
    try {
      final rootPath = await _getCacheDirectoryPath();
      final directory = Directory(rootPath);
      if (!await directory.exists()) {
        return;
      }

      final entries = <_CachedEntry>[];
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        try {
          final stat = await entity.stat();
          entries.add(
            _CachedEntry(
              file: entity,
              size: stat.size,
              lastModified: stat.modified,
            ),
          );
        } catch (error, stackTrace) {
          // Failed to stat file
        }
      }

      var totalSize = entries.fold<int>(0, (sum, entry) => sum + entry.size);
      if (totalSize <= maxCacheSizeBytes) {
        return;
      }

      entries.sort((a, b) => a.lastModified.compareTo(b.lastModified));

      for (final entry in entries) {
        if (totalSize <= maxCacheSizeBytes) {
          break;
        }
        try {
          await entry.file.delete();
          totalSize -= entry.size;
        } catch (error, stackTrace) {
          // Failed to delete file
        }
      }
    } catch (error, stackTrace) {
      // Cache cleanup failed
    }
  }

  static String composeKey(String cid, ImageVariant variant) => _composeKey(cid, variant);

  static String _composeKey(String cid, ImageVariant variant) {
    final sanitized = _sanitizeCid(cid);
    if (sanitized.isEmpty) {
      return sanitized;
    }
    final suffix = variant.suffix;
    return suffix.isEmpty ? sanitized : '${sanitized}_$suffix';
  }

  static Future<Uint8List> ensureVariant(
    String cid,
    Uint8List originalBytes, {
    ImageVariant variant = ImageVariant.medium,
  }) {
    if (variant == ImageVariant.original) {
      return Future.value(originalBytes);
    }

    final key = composeKey(cid, variant);
    final existing = _variantGenerationTasks[key];
    if (existing != null) {
      return existing;
    }

    final task = _generateVariant(cid, originalBytes, variant);
    _variantGenerationTasks[key] = task;
    return task.whenComplete(() => _variantGenerationTasks.remove(key));
  }

  static Future<Uint8List> _generateVariant(String cid, Uint8List originalBytes, ImageVariant variant) async {
    try {
      final codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: variant.targetWidth,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode thumbnail for $cid');
      }
      return byteData.buffer.asUint8List();
    } catch (error, stackTrace) {
      rethrow;
    }
  }
}

class _CachedEntry {
  _CachedEntry({required this.file, required this.size, required this.lastModified});

  final File file;
  final int size;
  final DateTime lastModified;
}

class _InMemoryCache {
  _InMemoryCache({required this.maxEntries, required this.maxBytes});

  final int maxEntries;
  final int maxBytes;

  final _entries = LinkedHashMap<String, _MemoryEntry>();
  int _totalBytes = 0;

  Uint8List? get(String key) {
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }
    _entries[key] = entry;
    return entry.bytes;
  }

  void put(String key, Uint8List bytes) {
    if (bytes.isEmpty) {
      return;
    }

    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }

    final data = Uint8List.fromList(bytes);

    final existing = _entries.remove(normalizedKey);
    if (existing != null) {
      _totalBytes -= existing.bytes.length;
    }

    final entry = _MemoryEntry(data);
    _entries[normalizedKey] = entry;
    _totalBytes += entry.bytes.length;

    _evictIfNeeded();
  }

  void remove(String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    final existing = _entries.remove(normalizedKey);
    if (existing != null) {
      _totalBytes -= existing.bytes.length;
    }
  }

  void _evictIfNeeded() {
    while (_entries.isNotEmpty &&
        ((maxEntries > 0 && _entries.length > maxEntries) || (maxBytes > 0 && _totalBytes > maxBytes))) {
      final oldestKey = _entries.keys.first;
      final oldestEntry = _entries.remove(oldestKey);
      if (oldestEntry != null) {
        _totalBytes -= oldestEntry.bytes.length;
      }
    }
  }
}

class _MemoryEntry {
  _MemoryEntry(this.bytes);

  final Uint8List bytes;
}
