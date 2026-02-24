import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/block_model.dart';

/// Block 元数据缓存服务
/// 提供内存和磁盘两级缓存，避免重复的 API 请求
class BlockCache {
  BlockCache._();
  static final BlockCache instance = BlockCache._();

  // 内存缓存：BID -> BlockModel
  final Map<String, _CacheEntry> _memoryCache = {};

  // 缓存配置
  static const int maxMemoryCacheSize = 100; // 最多缓存 100 个 Block
  static const Duration cacheTTL = Duration(days: 3); // 缓存有效期 3 天
  static const String _cachePrefix = 'block_cache_';

  /// 获取 Block 数据，优先从缓存读取
  /// 返回 null 表示缓存未命中，需要从 API 获取
  Future<BlockModel?> get(String bid) async {
    if (bid.trim().isEmpty) return null;

    final trimmedBid = bid.trim();

    // 1. 检查内存缓存
    final memoryEntry = _memoryCache[trimmedBid];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      debugPrint('[BlockCache] Memory cache hit: $trimmedBid');
      memoryEntry.updateAccessTime();
      return memoryEntry.block;
    }

    // 2. 检查磁盘缓存
    try {
      final prefs = await SharedPreferences.getInstance();
      final diskData = prefs.getString('$_cachePrefix$trimmedBid');
      
      if (diskData != null) {
        final json = jsonDecode(diskData) as Map<String, dynamic>;
        final timestamp = json['timestamp'] as int?;
        final blockData = json['data'] as Map<String, dynamic>?;

        if (timestamp != null && blockData != null) {
          final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final age = DateTime.now().difference(cacheTime);

          if (age < cacheTTL) {
            debugPrint('[BlockCache] Disk cache hit: $trimmedBid (age: ${age.inMinutes}m)');
            final block = BlockModel(data: blockData);
            
            // 更新到内存缓存
            _putMemory(trimmedBid, block);
            
            return block;
          } else {
            debugPrint('[BlockCache] Disk cache expired: $trimmedBid (age: ${age.inMinutes}m)');
            // 过期数据，删除
            await _removeDisk(trimmedBid);
          }
        }
      }
    } catch (e) {
      debugPrint('[BlockCache] Disk cache read error: $e');
      // 磁盘缓存读取失败，删除损坏的数据
      await _removeDisk(trimmedBid);
    }

    debugPrint('[BlockCache] Cache miss: $trimmedBid');
    return null;
  }

  /// 保存 Block 数据到缓存
  Future<void> put(String bid, BlockModel block) async {
    if (bid.trim().isEmpty) return;

    final trimmedBid = bid.trim();

    // 保存到内存缓存
    _putMemory(trimmedBid, block);

    // 保存到磁盘缓存
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': block.data,
      };
      await prefs.setString(
        '$_cachePrefix$trimmedBid',
        jsonEncode(cacheData),
      );
      debugPrint('[BlockCache] Saved to cache: $trimmedBid');
    } catch (e) {
      debugPrint('[BlockCache] Disk cache write error: $e');
    }
  }

  /// 清除指定 Block 的缓存
  Future<void> remove(String bid) async {
    if (bid.trim().isEmpty) return;

    final trimmedBid = bid.trim();
    _memoryCache.remove(trimmedBid);
    await _removeDisk(trimmedBid);
    debugPrint('[BlockCache] Removed from cache: $trimmedBid');
  }

  /// 清除所有缓存
  Future<void> clear() async {
    _memoryCache.clear();
    
    // 清除所有磁盘缓存
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final cacheKeys = allKeys.where((key) => key.startsWith(_cachePrefix));
      
      for (final key in cacheKeys) {
        await prefs.remove(key);
      }
      debugPrint('[BlockCache] Cleared all cache (${cacheKeys.length} entries)');
    } catch (e) {
      debugPrint('[BlockCache] Clear cache error: $e');
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getStats() {
    return {
      'memorySize': _memoryCache.length,
      'maxMemorySize': maxMemoryCacheSize,
      'ttlHours': cacheTTL.inHours,
    };
  }

  // 内部方法：保存到内存缓存
  void _putMemory(String bid, BlockModel block) {
    // LRU 淘汰：如果超过最大容量，删除最久未访问的条目
    if (_memoryCache.length >= maxMemoryCacheSize) {
      _evictLRU();
    }

    _memoryCache[bid] = _CacheEntry(block);
  }

  // 内部方法：LRU 淘汰
  void _evictLRU() {
    if (_memoryCache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _memoryCache.entries) {
      if (oldestTime == null || entry.value.lastAccessTime.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccessTime;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _memoryCache.remove(oldestKey);
      debugPrint('[BlockCache] Evicted from memory: $oldestKey');
    }
  }

  // 内部方法：从磁盘删除
  Future<void> _removeDisk(String bid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$bid');
    } catch (e) {
      debugPrint('[BlockCache] Disk cache delete error: $e');
    }
  }
}

/// 缓存条目
class _CacheEntry {
  _CacheEntry(this.block)
      : createdTime = DateTime.now(),
        lastAccessTime = DateTime.now();

  final BlockModel block;
  final DateTime createdTime;
  DateTime lastAccessTime;

  bool get isExpired {
    final age = DateTime.now().difference(createdTime);
    return age >= BlockCache.cacheTTL;
  }

  void updateAccessTime() {
    lastAccessTime = DateTime.now();
  }
}
