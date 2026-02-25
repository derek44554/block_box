import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 音频缓存辅助类，负责音频文件的本地缓存管理
class AudioCacheHelper {
  AudioCacheHelper._();

  static const String _cacheSubDir = 'audio_cache';

  /// 获取音频缓存目录
  static Future<Directory> getCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheSubDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 根据 CID 生成缓存文件路径
  static Future<File> _getCacheFile(String cid, String extension) async {
    final dir = await getCacheDirectory();
    // 使用 CID 作为文件名，加上扩展名
    final fileName = '$cid$extension';
    return File('${dir.path}/$fileName');
  }

  /// 检查音频是否已缓存
  static Future<File?> getCachedAudio(String cid, String extension) async {
    try {
      final file = await _getCacheFile(cid, extension);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 保存音频到缓存
  static Future<File> saveAudioToCache(
    String cid,
    Uint8List bytes,
    String extension,
  ) async {
    try {
      final file = await _getCacheFile(cid, extension);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      rethrow;
    }
  }

  /// 删除指定 CID 的缓存
  static Future<void> deleteCachedAudio(String cid, String extension) async {
    try {
      final file = await _getCacheFile(cid, extension);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Deletion failed
    }
  }

  /// 清空所有音频缓存
  static Future<void> clearAllCache() async {
    try {
      final dir = await getCacheDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      // Cleanup failed
    }
  }

  /// 获取缓存大小（字节）
  static Future<int> getCacheSize() async {
    try {
      final dir = await getCacheDirectory();
      if (!await dir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// 获取缓存文件数量
  static Future<int> getCacheCount() async {
    try {
      final dir = await getCacheDirectory();
      if (!await dir.exists()) {
        return 0;
      }

      int count = 0;
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          count++;
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 格式化缓存大小（人类可读）
  static String formatCacheSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
