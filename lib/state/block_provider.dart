import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:block_app/core/models/block_model.dart';

/// Global BlockProvider for managing Block state across all pages
/// 
/// This provider solves the stale data bug where list pages show outdated
/// Block data after detail pages save changes. Detail pages call updateBlock()
/// after successful save, and list pages listen to this provider to receive
/// updates automatically.
/// 
/// Features:
/// - Global state management for all Blocks
/// - Automatic notification to all listeners when Blocks update
/// - LRU cache strategy to limit memory usage
/// - Handles multi-level navigation scenarios (A→B→C→D)
class BlockProvider extends ChangeNotifier {
  BlockProvider({int maxCacheSize = 1000}) : _maxCacheSize = maxCacheSize;

  final int _maxCacheSize;
  
  /// LRU cache: Maps BID to BlockModel
  /// LinkedHashMap maintains insertion order for LRU implementation
  final LinkedHashMap<String, BlockModel> _blockCache = LinkedHashMap();

  /// Get a Block by BID
  /// Returns null if Block is not in cache
  BlockModel? getBlock(String bid) {
    if (!_blockCache.containsKey(bid)) {
      return null;
    }
    
    // Move to end (most recently used) for LRU
    final block = _blockCache.remove(bid);
    if (block != null) {
      _blockCache[bid] = block;
    }
    
    return block;
  }

  /// Update a Block in the cache and notify all listeners
  /// 
  /// This should be called by detail pages after successful save.
  /// All list pages listening to this provider will be notified
  /// and can update their local state accordingly.
  void updateBlock(BlockModel block) {
    final bid = block.bid;
    if (bid == null || bid.isEmpty) {
      return;
    }

    // Remove old entry if exists (for LRU reordering)
    _blockCache.remove(bid);
    
    // Add to end (most recently used)
    _blockCache[bid] = block;
    
    // Enforce cache size limit (LRU eviction)
    if (_blockCache.length > _maxCacheSize) {
      // Remove oldest entry (first in LinkedHashMap)
      final oldestKey = _blockCache.keys.first;
      _blockCache.remove(oldestKey);
    }

    // Notify all listeners (list pages, card widgets, etc.)
    notifyListeners();
  }

  /// Remove a Block from the cache
  /// 
  /// This can be called when a Block is deleted or should be removed
  /// from the cache for any reason.
  void removeBlock(String bid) {
    if (_blockCache.containsKey(bid)) {
      _blockCache.remove(bid);
      notifyListeners();
    }
  }

  /// Clear all cached Blocks
  /// 
  /// This can be used when switching accounts or clearing app data.
  void clearCache() {
    _blockCache.clear();
    notifyListeners();
  }

  /// Get the current cache size
  int get cacheSize => _blockCache.length;

  /// Check if a Block is in the cache
  bool hasBlock(String bid) => _blockCache.containsKey(bid);
}
