import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/photo_models.dart';


const _photoCollectionsKey = 'photo_collections_data';

class PhotoProvider extends ChangeNotifier {
  PhotoProvider() {
    _restore();
  }

  List<PhotoCollection> _collections = const [];

  List<PhotoCollection> get collections => List.unmodifiable(_collections);

  List<PhotoCollection> get albumCollections =>
      _collections.where((collection) => collection.isAlbum).toList(growable: false);

  Future<void> setCollections(List<PhotoCollection> collections) async {
    _collections = List.unmodifiable(collections);
    await _persist();
    notifyListeners();
  }

  Future<void> addCollection(PhotoCollection collection) async {
    final existingIndex = _collections.indexWhere((item) => item.bid == collection.bid);
    List<PhotoCollection> updated;
    if (existingIndex >= 0) {
      updated = [..._collections];
      updated[existingIndex] = collection;
    } else {
      updated = [..._collections, collection];
    }
    _collections = List.unmodifiable(updated);
    await _persist();
    notifyListeners();
  }

  Future<void> removeCollection(String bid) async {
    _collections = List.unmodifiable(_collections.where((item) => item.bid != bid));
    await _persist();
    notifyListeners();
  }

  Future<void> toggleAlbum(String bid, bool isAlbum) async {
    final updated = _collections.map((entry) {
      if (entry.bid == bid) {
        return entry.copyWith(isAlbum: isAlbum);
      }
      return entry;
    }).toList(growable: false);
    _collections = List.unmodifiable(updated);
    await _persist();
    notifyListeners();
  }

  Future<void> updateCollectionBlock(String bid, Map<String, dynamic> block) async {
    final updated = _collections.map((entry) {
      if (entry.bid == bid) {
        return entry.copyWith(block: block);
      }
      return entry;
    }).toList(growable: false);
    _collections = List.unmodifiable(updated);
    await _persist();
    notifyListeners();
  }

  Future<void> reorderCollections(int oldIndex, int newIndex) async {
    final updated = [..._collections];
    final normalizedNewIndex = _normalizeNewIndex(oldIndex, newIndex, updated.length);
    final entry = updated.removeAt(oldIndex);
    updated.insert(normalizedNewIndex, entry);
    _collections = List.unmodifiable(updated);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _collections.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_photoCollectionsKey, payload);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getStringList(_photoCollectionsKey);
    if (payload == null || payload.isEmpty) {
      _collections = const [];
      notifyListeners();
      return;
    }

    // 在后台 Isolate 中进行 JSON 解码，避免阻塞主线程
    try {
      final restored = await compute(_parseCollections, payload);
      _collections = restored;
    } catch (e) {
      debugPrint('Failed to restore photo collections: $e');
      _collections = const [];
    }

    notifyListeners();
  }

  // 静态方法，用于 compute 调用
  static List<PhotoCollection> _parseCollections(List<String> payload) {
    return payload
        .map((entry) => PhotoCollection.fromJson(jsonDecode(entry) as Map<String, dynamic>))
        .toList(growable: false);
  }

  int _normalizeNewIndex(int oldIndex, int newIndex, int length) {
    var target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    if (target < 0) {
      target = 0;
    }
    if (target >= length) {
      target = length - 1;
    }
    return target;
  }
}

