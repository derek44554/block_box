import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/aggregation_models.dart';

const _aggregationItemsKey = 'aggregation_items';
const _aggregationSelectionKey = 'aggregation_selection';
const _aggregationGridLayoutKey = 'aggregation_grid_layout_ids';

class AggregationProvider extends ChangeNotifier {
  AggregationProvider() {
    _restore();
  }

  int _counter = 0;

  List<AggregationItem> _items = const [];
  String? _selectedItemId;
  Set<String> _gridLayoutItemIds = <String>{}; // 记录使用网格布局的项ID

  List<AggregationItem> get items => List.unmodifiable(_items);
  String? get selectedItemId => _selectedItemId;
  Set<String> get gridLayoutItemIds => Set.unmodifiable(_gridLayoutItemIds);

  /// 添加新的聚集项
  Future<void> addItem(String title, String model) async {
    final value = title.trim();
    if (value.isEmpty) {
      return;
    }
    final item = AggregationItem(
      id: _nextId(),
      title: value,
      model: model,
      count: 0,
    );
    _items = [..._items, item];
    await _persist();
    notifyListeners();
  }

  /// 更新聚集项标题
  Future<void> updateItemTitle(String itemId, String newTitle) async {
    final value = newTitle.trim();
    if (value.isEmpty) {
      return;
    }
    _items = _items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(title: value);
      }
      return item;
    }).toList();
    await _persist();
    notifyListeners();
  }

  /// 更新聚集项的model类型
  Future<void> updateItemModel(String itemId, String newModel) async {
    _items = _items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(model: newModel);
      }
      return item;
    }).toList();
    await _persist();
    notifyListeners();
  }

  /// 更新聚集项的数量
  void updateItemCount(String itemId, int count) {
    _items = _items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(count: count);
      }
      return item;
    }).toList();
    // 不持久化count，因为它是动态计算的
    notifyListeners();
  }

  /// 删除聚集项
  Future<void> removeItem(String id) async {
    _items = _items.where((item) => item.id != id).toList();
    if (_selectedItemId == id) {
      _selectedItemId = null;
    }
    await _persist();
    notifyListeners();
  }

  /// 对聚集项进行排序
  Future<void> reorderItems(int oldIndex, int newIndex) async {
    final updated = [..._items];
    final normalizedNewIndex = _normalizeNewIndex(oldIndex, newIndex, updated.length);
    final item = updated.removeAt(oldIndex);
    updated.insert(normalizedNewIndex, item);
    _items = updated;
    await _persist();
    notifyListeners();
  }

  /// 设置当前选中的项
  Future<void> setSelectedItem(String? itemId) async {
    _selectedItemId = itemId;
    final prefs = await SharedPreferences.getInstance();
    if (itemId != null) {
      await prefs.setString(_aggregationSelectionKey, itemId);
    } else {
      await prefs.remove(_aggregationSelectionKey);
    }
    notifyListeners();
  }

  /// 检查某个项是否使用网格布局
  bool isGridLayoutItem(String itemId) {
    final value = itemId.trim();
    if (value.isEmpty) {
      return false;
    }
    return _gridLayoutItemIds.contains(value);
  }

  /// 设置项的布局模式
  Future<void> setGridLayoutForItem(String itemId, bool isGridLayout) async {
    final value = itemId.trim();
    if (value.isEmpty) {
      return;
    }
    final updated = Set<String>.from(_gridLayoutItemIds);
    final changed = isGridLayout ? updated.add(value) : updated.remove(value);
    if (!changed) {
      return;
    }
    _gridLayoutItemIds = updated;
    await _persist();
    notifyListeners();
  }

  /// 为项添加标签
  Future<void> addTagToItem(String itemId, String tag) async {
    final value = tag.trim();
    if (value.isEmpty) {
      return;
    }
    _items = _items.map((item) {
      if (item.id == itemId) {
        if (item.tags.contains(value)) {
          return item;
        }
        final updatedTags = [...item.tags, value];
        return item.copyWith(tags: updatedTags);
      }
      return item;
    }).toList();
    await _persist();
    notifyListeners();
  }

  /// 从项中删除标签
  Future<void> removeTagFromItem(String itemId, String tag) async {
    _items = _items.map((item) {
      if (item.id == itemId) {
        final updatedTags = item.tags.where((t) => t != tag).toList();
        return item.copyWith(tags: updatedTags);
      }
      return item;
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
    final itemsPayload = _items.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_aggregationItemsKey, itemsPayload);
    await prefs.setStringList(_aggregationGridLayoutKey, _gridLayoutItemIds.toList());
    if (_selectedItemId != null) {
      await prefs.setString(_aggregationSelectionKey, _selectedItemId!);
    } else {
      await prefs.remove(_aggregationSelectionKey);
    }
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_aggregationItemsKey);
    final rawSelection = prefs.getString(_aggregationSelectionKey);
    final rawGridIds = prefs.getStringList(_aggregationGridLayoutKey);

    if (rawItems != null) {
      _items = rawItems
          .map((item) => AggregationItem.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
      _counter = _calculateCounter();
    }

    if (rawSelection != null) {
      _selectedItemId = rawSelection;
    }

    if (rawGridIds != null) {
      _gridLayoutItemIds = rawGridIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    notifyListeners();
  }

  String _nextId() {
    _counter += 1;
    return 'aggregation-$_counter';
  }

  int _calculateCounter() {
    var maxValue = 0;
    for (final item in _items) {
      final match = RegExp(r'aggregation-(\d+)$').firstMatch(item.id);
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

