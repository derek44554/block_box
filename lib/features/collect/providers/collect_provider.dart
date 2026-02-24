import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collect_models.dart';

const _collectTagsKey = 'collect_tags';
const _collectEntriesKey = 'collect_entries';
const _collectSelectionKey = 'collect_selection';
const _gridLayoutBidsKey = 'collect_grid_layout_bids';

class CollectProvider extends ChangeNotifier {
  CollectProvider() {
    _restore();
  }

  int _counter = 0;

  List<CollectTag> _tags = const [];
  List<CollectEntry> _entries = const [];
  Set<String> _gridLayoutBids = <String>{};
  _CollectSelectionState? _persistedSelection;

  List<CollectTag> get tags => List.unmodifiable(_tags);
  List<CollectEntry> get entries => List.unmodifiable(_entries);
  _CollectSelectionState? get persistedSelection => _persistedSelection;
  Set<String> get gridLayoutBids => Set.unmodifiable(_gridLayoutBids);

  bool isGridLayoutBid(String bid) {
    final value = bid.trim();
    if (value.isEmpty) {
      return false;
    }
    return _gridLayoutBids.contains(value);
  }

  Future<void> setPersistedSelection(String groupId, String itemBid) async {
    _persistedSelection = _CollectSelectionState(groupId: groupId, itemBid: itemBid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_collectSelectionKey, jsonEncode(_persistedSelection!.toJson()));
    notifyListeners();
  }

  Future<void> clearPersistedSelection() async {
    _persistedSelection = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_collectSelectionKey);
    notifyListeners();
  }

  Future<void> addTag(String name) async {
    final value = name.trim();
    if (value.isEmpty) {
      return;
    }
    if (_tags.any((tag) => tag.name == value)) {
      return;
    }
    _tags = [..._tags, CollectTag(name: value)];
    await _persist();
    notifyListeners();
  }

  Future<void> removeTag(String name) async {
    _tags = _tags.where((tag) => tag.name != name).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> addEntry(String title) async {
    final value = title.trim();
    if (value.isEmpty) {
      return;
    }
    final entry = CollectEntry(id: _nextId(), title: value, items: const []);
    _entries = [..._entries, entry];
    await _persist();
    notifyListeners();
  }

  Future<void> updateEntryTitle(String entryId, String newTitle) async {
    final value = newTitle.trim();
    if (value.isEmpty) {
      return;
    }
    _entries = _entries.map((entry) {
      if (entry.id == entryId) {
        return entry.copyWith(title: value);
      }
      return entry;
    }).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> setGridLayoutForBid(String bid, bool isGridLayout) async {
    final value = bid.trim();
    if (value.isEmpty) {
      return;
    }
    final updated = Set<String>.from(_gridLayoutBids);
    final changed = isGridLayout ? updated.add(value) : updated.remove(value);
    if (!changed) {
      return;
    }
    _gridLayoutBids = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> removeEntry(String id) async {
    _entries = _entries.where((entry) => entry.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> addItem(String entryId, CollectItem item) async {
    _entries = _entries.map((entry) {
      if (entry.id == entryId) {
        final items = [...entry.items, item];
        return entry.copyWith(items: items);
      }
      return entry;
    }).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> removeItem(String entryId, String bid) async {
    _entries = _entries.map((entry) {
      if (entry.id == entryId) {
        final items = entry.items.where((item) => item.bid != bid).toList();
        return entry.copyWith(items: items);
      }
      return entry;
    }).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> updateItemTitle(String entryId, String bid, String newTitle) async {
    final value = newTitle.trim();
    if (value.isEmpty) {
      return;
    }
    _entries = _entries.map((entry) {
      if (entry.id == entryId) {
        final items = entry.items
            .map((item) => item.bid == bid ? item.copyWith(name: value) : item)
            .toList();
        return entry.copyWith(items: items);
      }
      return entry;
    }).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> reorderTags(int oldIndex, int newIndex) async {
    final updated = [..._tags];
    final normalizedNewIndex = _normalizeNewIndex(oldIndex, newIndex, updated.length);
    final tag = updated.removeAt(oldIndex);
    updated.insert(normalizedNewIndex, tag);
    _tags = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> reorderEntries(int oldIndex, int newIndex) async {
    final updated = [..._entries];
    final normalizedNewIndex = _normalizeNewIndex(oldIndex, newIndex, updated.length);
    final entry = updated.removeAt(oldIndex);
    updated.insert(normalizedNewIndex, entry);
    _entries = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> reorderItems(String entryId, int oldIndex, int newIndex) async {
    _entries = _entries.map((entry) {
      if (entry.id != entryId) {
        return entry;
      }
      final items = [...entry.items];
      final normalizedNewIndex = _normalizeNewIndex(oldIndex, newIndex, items.length);
      final item = items.removeAt(oldIndex);
      items.insert(normalizedNewIndex, item);
      return entry.copyWith(items: items);
    }).toList();
    await _persist();
    notifyListeners();
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

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final tagsPayload = _tags.map((tag) => jsonEncode(tag.toJson())).toList();
    final entriesPayload = _entries.map((entry) => jsonEncode(entry.toJson())).toList();
    await prefs.setStringList(_collectTagsKey, tagsPayload);
    await prefs.setStringList(_collectEntriesKey, entriesPayload);
    await prefs.setStringList(_gridLayoutBidsKey, _gridLayoutBids.toList());
    if (_persistedSelection != null) {
      await prefs.setString(_collectSelectionKey, jsonEncode(_persistedSelection!.toJson()));
    } else {
      await prefs.remove(_collectSelectionKey);
    }
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTags = prefs.getStringList(_collectTagsKey);
    final rawEntries = prefs.getStringList(_collectEntriesKey);
    final rawSelection = prefs.getString(_collectSelectionKey);
    final rawGridBids = prefs.getStringList(_gridLayoutBidsKey);

    if (rawTags != null) {
      _tags = rawTags
          .map((tag) => CollectTag.fromJson(jsonDecode(tag) as Map<String, dynamic>))
          .toList();
    }

    if (rawEntries != null) {
      _entries = rawEntries
          .map((entry) => CollectEntry.fromJson(jsonDecode(entry) as Map<String, dynamic>))
          .toList();
      _counter = _calculateCounter();
    }

    if (rawSelection != null) {
      try {
        final data = jsonDecode(rawSelection) as Map<String, dynamic>;
        _persistedSelection = _CollectSelectionState.fromJson(data);
      } catch (_) {
        _persistedSelection = null;
      }
    }

    if (rawGridBids != null) {
      _gridLayoutBids = rawGridBids
          .map((bid) => bid.trim())
          .where((bid) => bid.isNotEmpty)
          .toSet();
    }

    notifyListeners();
  }

  String _nextId() {
    _counter += 1;
    return 'collect-$_counter';
  }

  int _calculateCounter() {
    var maxValue = 0;
    for (final entry in _entries) {
      final match = RegExp(r'collect-(\d+)$').firstMatch(entry.id);
      if (match != null) {
        final value = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (value > maxValue) {
          maxValue = value;
        }
      }
    }
    return maxValue;
  }
}

class _CollectSelectionState {
  const _CollectSelectionState({required this.groupId, required this.itemBid});

  factory _CollectSelectionState.fromJson(Map<String, dynamic> json) {
    return _CollectSelectionState(
      groupId: json['groupId'] as String,
      itemBid: json['itemBid'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'itemBid': itemBid,
      };

  final String groupId;
  final String itemBid;
}
