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
        debugPrint('[AudioCacheHelper] 找到缓存: $cid$extension');
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('[AudioCacheHelper] 检查缓存失败: $e');
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
      debugPrint('[AudioCacheHelper] 保存缓存: $cid$extension (${bytes.length} bytes)');
      return file;
    } catch (e) {
      debugPrint('[AudioCacheHelper] 保存缓存失败: $e');
      rethrow;
    }
  }

  /// 删除指定 CID 的缓存
  static Future<void> deleteCachedAudio(String cid, String extension) async {
    try {
      final file = await _getCacheFile(cid, extension);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioCacheHelper] 删除缓存: $cid$extension');
      }
    } catch (e) {
      debugPrint('[AudioCacheHelper] 删除缓存失败: $e');
    }
  }

  /// 清空所有音频缓存
  static Future<void> clearAllCache() async {
    try {
      final dir = await getCacheDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('[AudioCacheHelper] 清空所有音频缓存');
      }
    } catch (e) {
      debugPrint('[AudioCacheHelper] 清空缓存失败: $e');
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
      debugPrint('[AudioCacheHelper] 获取缓存大小失败: $e');
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
      debugPrint('[AudioCacheHelper] 获取缓存数量失败: $e');
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
