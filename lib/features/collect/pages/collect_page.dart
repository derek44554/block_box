import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:block_app/core/network/api/block_api.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';
import 'package:block_app/core/widgets/dialogs/confirmation_dialog.dart';

import '../../../components/block/block_card_factory.dart';
import '../../../components/block/block_grid_layout.dart';
import '../../../core/models/block_model.dart';
import '../../../core/widgets/common/action_sheet.dart';
import '../../../core/widgets/layouts/segmented_page_scaffold.dart';
import '../../../state/connection_provider.dart';
import '../../../state/block_provider.dart';
import '../models/collect_models.dart';
import '../providers/collect_provider.dart';
import '../widgets/collect_collection_group.dart';
import '../../link/widgets/add_link_dialog.dart';
import '../../link/services/file_upload_service.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  List<BlockModel> _activeBlocks = const [];
  _CollectSelection? _selectedCollection;
  bool _isEditingOrder = false;
  bool _isLoadingBlocks = false;
  bool _isSubmitting = false;
  int _currentPage = 1;
  int _pageLimit = 10;
  String? _activeRequestKey;
  bool _hasMoreBlocks = true;
  bool _selectionRestored = false;
  VoidCallback? _providerListener;
  VoidCallback? _blockProviderListener;
  String? _modelFilter;
  String? _tagFilter;
  List<String> _availableLinkTags = const <String>[];
  bool _isLoadingFilterData = false;
  bool _hasLoadedFilterData = false;
  bool _isDragging = false;
  bool _isUploading = false;
  String? _sortOrder; // 排序顺序: "desc", "asc", 或 null

  static const Map<String, String> _modelOptions = {
    '34c00af3a2d32129327766285361b0c1': '普通块',
    '93b133932057a254cc15d0f09c91ca98': '文档',
    '52da1e115d0a764b43c90f6b43284aa9': '文章',
    '81b0bc8db4f678300d199f5b34729282': '服务',
    '1635e536a5a331a283f9da56b7b51774': '集合',
    'c4238dd0d3d95db7b473adb449f6d282': '图片',
    '71b6eb41f026842b3df6b126dfe11c29': '用户',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CollectProvider>();
      if (provider.entries.isNotEmpty && !_selectionRestored) {
        _restoreSelection(provider);
      } else if (!_selectionRestored) {
        _providerListener = () {
          final entries = provider.entries;
          if (entries.isNotEmpty && !_selectionRestored) {
            _restoreSelection(provider);
            provider.removeListener(_providerListener!);
            _providerListener = null;
          }
        };
        provider.addListener(_providerListener!);
      }
      
      // Listen to BlockProvider for Block updates
      _blockProviderListener = _onBlockProviderUpdate;
      context.read<BlockProvider>().addListener(_blockProviderListener!);
    });
  }

  @override
  void dispose() {
    if (_providerListener != null) {
      try {
        context.read<CollectProvider>().removeListener(_providerListener!);
      } catch (e) {
        // Ignore errors during cleanup
      }
      _providerListener = null;
    }
    // Remove BlockProvider listener
    if (_blockProviderListener != null) {
      try {
        context.read<BlockProvider>().removeListener(_blockProviderListener!);
      } catch (e) {
        // Ignore errors during cleanup
      }
      _blockProviderListener = null;
    }
    super.dispose();
  }

  /// Handle BlockProvider updates
  void _onBlockProviderUpdate() {
    if (!mounted) return;
    
    try {
      final blockProvider = context.read<BlockProvider>();
      bool hasUpdates = false;
      
      // Update _activeBlocks if any Block in the list was updated
      final updatedBlocks = <BlockModel>[];
      for (final block in _activeBlocks) {
        final bid = block.maybeString('bid');
        if (bid != null) {
          final updatedBlock = blockProvider.getBlock(bid);
          if (updatedBlock != null) {
            updatedBlocks.add(updatedBlock);
            hasUpdates = true;
          } else {
            updatedBlocks.add(block);
          }
        } else {
          updatedBlocks.add(block);
        }
      }
      
      // Trigger UI update if any Block was updated
      if (hasUpdates) {
        setState(() {
          _activeBlocks = updatedBlocks;
        });
      }
    } catch (e, stack) {
      // Ignore errors in block update listener
    }
  }

  void _restoreSelection(CollectProvider provider) async {
    final persisted = provider.persistedSelection;
    if (persisted == null) {
      return;
    }
    CollectEntry? entry;
    CollectItem? item;
    try {
      entry = provider.entries.firstWhere(
        (element) => element.id == persisted.groupId,
      );
    } catch (_) {
      entry = null;
    }
    if (entry == null) {
      return;
    }
    try {
      item = entry.items.firstWhere(
        (element) => element.bid == persisted.itemBid,
      );
    } catch (_) {
      item = null;
    }
    if (item == null) {
      return;
    }
    final resolvedEntry = entry;
    final resolvedItem = item;
    setState(() {
      _selectedCollection = _CollectSelection(
        groupId: resolvedEntry.id,
        itemBid: resolvedItem.bid,
      );
      _activeBlocks = const [];
      _hasMoreBlocks = true;
      _currentPage = 1;
      _selectionRestored = true;
    });
    _loadCollectionSettings(resolvedItem.bid);
    _fetchLinkBlocks(context: context, bid: resolvedItem.bid, page: 1);
  }

  void _handleCollectionTap(String entryId, CollectItem item) {
    setState(() {
      final current = _selectedCollection;
      if (current != null &&
          current.groupId == entryId &&
          current.itemBid == item.bid) {
        _selectedCollection = null;
        _modelFilter = null;
        _tagFilter = null;
        _sortOrder = null;
        _hasLoadedFilterData = false;
        context.read<CollectProvider>().clearPersistedSelection();
      } else {
        _selectedCollection = _CollectSelection(
          groupId: entryId,
          itemBid: item.bid,
        );
        _activeBlocks = const [];
        _hasMoreBlocks = true;
        _currentPage = 1;
        _modelFilter = null;
        _tagFilter = null;
        _sortOrder = null;
        _hasLoadedFilterData = false;
        context.read<CollectProvider>().setPersistedSelection(
          entryId,
          item.bid,
        );
      }
    });

    if (_selectedCollection != null) {
      _loadCollectionSettings(item.bid);
      _fetchLinkBlocks(context: context, bid: item.bid, page: 1);
      _loadAvailableLinkTags(item.bid);
    } else {
      setState(() {
        _activeBlocks = const [];
      });
    }
  }

  void _toggleEditingMode() {
    setState(() {
      _isEditingOrder = !_isEditingOrder;
    });
  }

  Future<void> _loadAvailableLinkTags(String bid) async {
    if (_hasLoadedFilterData) {
      return;
    }
    if (bid.trim().isEmpty) {
      return;
    }

    setState(() {
      _isLoadingFilterData = true;
    });

    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final response = await api.getBlock(bid: bid.trim());
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final tags = _extractLinkTags(data);
        if (mounted) {
          setState(() {
            _availableLinkTags = tags;
            if (_tagFilter != null &&
                !_availableLinkTags.contains(_tagFilter!)) {
              _tagFilter = null;
            }
            _hasLoadedFilterData = true;
          });
        }
      }
    } catch (error) {
      // Ignore errors loading link tags
    } finally {
      if (mounted) {
        setState(() => _isLoadingFilterData = false);
      }
    }
  }

  List<String> _extractLinkTags(Map<String, dynamic> data) {
    final tags = <String>{};

    void collect(dynamic value) {
      if (value is List) {
        for (final item in value) {
          if (item is String) {
            final trimmed = item.trim();
            if (trimmed.isNotEmpty) {
              tags.add(trimmed);
            }
          }
        }
      }
    }

    collect(data['link_tag']);
    collect(data['link_tags']);

    final sorted = tags.toList()..sort((a, b) => a.compareTo(b));
    return sorted;
  }

  bool get _hasActiveFilter =>
      (_modelFilter != null && _modelFilter!.isNotEmpty) ||
      (_tagFilter != null && _tagFilter!.isNotEmpty);

  Future<void> _showFilterDialog() async {
    final selectedBid = _selectedCollection?.itemBid;
    if (selectedBid == null || selectedBid.trim().isEmpty) {
      return;
    }

    if (!_hasLoadedFilterData && !_isLoadingFilterData) {
      await _loadAvailableLinkTags(selectedBid);
      if (!mounted) return;
    }

    String? tempModel = _modelFilter;
    String? tempTag = _tagFilter;

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AppDialog(
              title: '筛选收藏',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BID 显示和复制区域
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'BID: ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            selectedBid,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // 复制到剪贴板
                            Clipboard.setData(ClipboardData(text: selectedBid));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('BID 已复制到剪贴板'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy,
                              size: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '模型类型',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('全部'),
                        selected: tempModel == null || tempModel!.isEmpty,
                        onSelected: (_) {
                          dialogSetState(() => tempModel = null);
                        },
                      ),
                      for (final entry in _modelOptions.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: tempModel == entry.key,
                          onSelected: (selected) {
                            dialogSetState(
                              () => tempModel = selected ? entry.key : null,
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '链接标签',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isLoadingFilterData && _availableLinkTags.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    )
                  else if (_availableLinkTags.isEmpty)
                    const Text(
                      '暂无链接标签',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('全部'),
                          selected: tempTag == null || tempTag!.isEmpty,
                          onSelected: (_) {
                            dialogSetState(() => tempTag = null);
                          },
                        ),
                        for (final tag in _availableLinkTags)
                          ChoiceChip(
                            label: Text(tag),
                            selected: tempTag == tag,
                            onSelected: (selected) {
                              dialogSetState(
                                () => tempTag = selected ? tag : null,
                              );
                            },
                          ),
                      ],
                    ),
                ],
              ),
              actions: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      dialogSetState(() {
                        tempModel = null;
                        tempTag = null;
                      });
                    },
                    child: const Text('重置'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop({'model': tempModel, 'tag': tempTag});
                    },
                    child: const Text('应用'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final newModel = result['model'];
    final newTag = result['tag'];

    if (newModel == _modelFilter && newTag == _tagFilter) {
      return;
    }

    setState(() {
      _modelFilter = newModel;
      _tagFilter = newTag;
      _activeBlocks = const [];
      _hasMoreBlocks = true;
      _currentPage = 1;
    });
    
    if (selectedBid != null) {
      _fetchLinkBlocks(context: context, bid: selectedBid, page: 1);
    }
  }

  void _clearFilters() {
    if (!_hasActiveFilter) {
      return;
    }
    final selectedBid = _selectedCollection?.itemBid;
    setState(() {
      _modelFilter = null;
      _tagFilter = null;
      _activeBlocks = const [];
      _hasMoreBlocks = true;
      _currentPage = 1;
    });
    if (selectedBid != null) {
      _fetchLinkBlocks(context: context, bid: selectedBid, page: 1);
    }
  }

  Future<void> _showAddToLinkDialog() async {
    final currentBid = _selectedCollection?.itemBid;
    if (currentBid == null || currentBid.trim().isEmpty) {
      return;
    }

    final targetBid = await showAddLinkDialog(context);
    if (targetBid == null || targetBid.trim().isEmpty) {
      return;
    }

    await _handleAddToLink(currentBid, targetBid.trim());
  }

  Future<void> _handleAddToLink(String currentBid, String targetBid) async {
    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);

      // 获取目标块的信息
      final targetBlockResponse = await api.getBlock(bid: targetBid);
      final targetData = targetBlockResponse['data'];
      if (targetData == null || targetData is! Map<String, dynamic>) {
        throw Exception('未找到指定 BID 对应的块');
      }

      // 修改目标块，将当前收藏的BID添加到目标块的link列表中
      final updatedData = Map<String, dynamic>.from(targetData);
      final links = (updatedData['link'] is List
          ? List<String>.from(updatedData['link'])
          : <String>[]);

      if (links.contains(currentBid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该收藏 BID 已存在目标块的链接列表中')),
        );
        return;
      }

      links.add(currentBid);
      updatedData['link'] = links;
      updatedData['bid'] = targetBid;

      // 提交目标块的修改请求
      await api.saveBlock(data: updatedData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已将收藏 BID 添加到目标块的链接中')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// 加载收藏的设置（排序等）
  Future<void> _loadCollectionSettings(String bid) async {
    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final response = await api.getBlock(bid: bid);
      final data = response['data'];
      
      if (data is Map<String, dynamic>) {
        final order = data['order'];
        if (mounted) {
          setState(() {
            _sortOrder = (order is String && order.isNotEmpty) ? order : null;
          });
        }
      }
    } catch (e) {
      // 忽略加载设置失败的错误，使用默认值
    }
  }

  /// 保存排序设置到收藏 Block
  Future<void> _saveSortOrder(String bid, String? order) async {
    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final response = await api.getBlock(bid: bid);
      final data = response['data'];
      
      if (data is Map<String, dynamic>) {
        final updatedData = Map<String, dynamic>.from(data);
        if (order != null && order.isNotEmpty) {
          updatedData['order'] = order;
        } else {
          updatedData.remove('order');
        }
        
        await api.saveBlock(data: updatedData);
        
        if (mounted) {
          context.read<BlockProvider>().updateBlock(BlockModel(data: updatedData));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存排序设置失败：$e')),
        );
      }
    }
  }

  /// 切换排序顺序
  Future<void> _toggleSortOrder(String bid) async {
    String? newOrder;
    if (_sortOrder == null) {
      newOrder = 'desc'; // 默认降序（最新的在前）
    } else if (_sortOrder == 'desc') {
      newOrder = 'asc'; // 切换到升序
    } else {
      newOrder = null; // 取消排序
    }

    setState(() {
      _sortOrder = newOrder;
      _activeBlocks = const [];
      _currentPage = 1;
      _hasMoreBlocks = true;
    });

    // 保存排序设置
    await _saveSortOrder(bid, newOrder);

    // 重新加载数据
    if (mounted) {
      await _fetchLinkBlocks(context: context, bid: bid, page: 1);
    }
  }

  Future<void> _fetchLinkBlocks({
    required BuildContext context,
    required String bid,
    required int page,
  }) async {
    if (_isLoadingBlocks) {
      return;
    }

    final requestKey = 'link#$bid#$page';
    _activeRequestKey = requestKey;
    setState(() {
      _isLoadingBlocks = true;
    });

    try {
      // 根据网格模式调整分页大小
      final selectedBid = _selectedCollection?.itemBid;
      final isGridMode = selectedBid != null &&
          context.read<CollectProvider>().isGridLayoutBid(selectedBid);
      final pageLimit = isGridMode ? 50 : 10;

      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final response = await api.getLinksByMain(
        bid: bid,
        page: page,
        limit: pageLimit,
        model: _modelFilter,
        tag: _tagFilter,
        order: _sortOrder,
      );

      if (!mounted || _activeRequestKey != requestKey) {
        return;
      }

      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('链接请求返回数据格式无效');
      }

      final items = data['items'];
      if (items is! List) {
        throw Exception('链接请求 items 数据格式无效');
      }

      final fetchedBlocks = items
          .whereType<Map<String, dynamic>>()
          .map((item) => BlockModel(data: item))
          .toList();

      setState(() {
        if (page == 1) {
          _activeBlocks = fetchedBlocks;
        } else {
          final existing = _activeBlocks
              .map((block) => block.data['bid'])
              .whereType<String>()
              .toSet();
          final merged = List<BlockModel>.from(_activeBlocks);
          for (final block in fetchedBlocks) {
            final blockBid = block.data['bid'];
            if (blockBid is String && existing.contains(blockBid)) {
              continue;
            }
            merged.add(block);
            if (blockBid is String) {
              existing.add(blockBid);
            }
          }
          _activeBlocks = merged;
        }
        _currentPage = data['page'] is int ? data['page'] as int : page;
        _pageLimit = data['limit'] is int ? data['limit'] as int : pageLimit;

        final total = data['count'];
        if (total is int) {
          _hasMoreBlocks = _activeBlocks.length < total;
        } else {
          _hasMoreBlocks = fetchedBlocks.isNotEmpty;
        }
      });
    } catch (error, stack) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载外链失败：${error.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (_activeRequestKey == requestKey) {
        _activeRequestKey = null;
      }
      if (mounted) {
        setState(() {
          _isLoadingBlocks = false;
        });
      }
    }
  }

  void _showAddEntryDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _EntryEditorDialog(
        onSubmit: (value) => context.read<CollectProvider>().addEntry(value),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, CollectEntry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => _ItemEditorDialog(
        onSubmit: (bid) => _handleAddItem(context, entry, bid),
      ),
    );
  }

  Future<void> _handleAddItem(
    BuildContext context,
    CollectEntry entry,
    String bid,
  ) async {
    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final response = await api.getBlock(bid: bid);
      final data =
          response['data'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final title = (data['name'] as String?)?.trim();
      if (title == null || title.isEmpty) {
        throw Exception('块数据缺少有效的 name');
      }

      final item = CollectItem(name: title, bid: bid);
      await context.read<CollectProvider>().addItem(entry.id, item);
    } catch (error, stack) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加失败：${error.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDeleteEntry(
    BuildContext context,
    CollectEntry entry,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppDialog(
          title: '确认删除分组？',
          content: Text(
            '分组 “${entry.title}” 删除后不可恢复，是否继续？',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('删除'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true) {
      await context.read<CollectProvider>().removeEntry(entry.id);
    }
  }

  Future<void> _showEntryOptions(
    BuildContext context,
    CollectEntry entry,
  ) async {
    final action = await showModalBottomSheet<_EntryAction>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return ActionSheet(
          title: '分组选项',
          actions: [
            ActionItem(
              label: '重命名分组',
              icon: Icons.edit_outlined,
              onTap: () => Navigator.of(context).pop(_EntryAction.rename),
            ),
            ActionItem(
              label: '删除分组',
              icon: Icons.delete_outline,
              isDestructive: true,
              onTap: () => Navigator.of(context).pop(_EntryAction.delete),
            ),
          ],
        );
      },
    );

    switch (action) {
      case _EntryAction.rename:
        await _handleRenameEntry(context, entry);
        break;
      case _EntryAction.delete:
        await _handleDeleteEntry(context, entry);
        break;
      case null:
        break;
    }
  }

  Future<void> _handleDeleteItem(
    BuildContext context,
    CollectEntry entry,
    CollectItem item,
  ) async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ActionSheet(
          title: '分组条目 "${item.name}" 的操作',
          actions: [
            ActionItem(
              label: '删除分组条目',
              icon: Icons.delete_outline,
              isDestructive: true,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    final confirm = await showConfirmationDialog(
      context: context,
      title: '确认删除该分组条目？',
      content: Text(
        '分组条目 "${item.name}" 删除后不可恢复，是否继续？',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      confirmText: '删除',
      isDestructive: true,
    );

    if (confirm == true) {
      await context.read<CollectProvider>().removeItem(entry.id, item.bid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectProvider = context.watch<CollectProvider>();
    CollectItem? currentItem;
    if (_selectedCollection != null) {
      try {
        final entry = collectProvider.entries
            .firstWhere((e) => e.id == _selectedCollection!.groupId);
        currentItem = entry.items
            .firstWhere((item) => item.bid == _selectedCollection!.itemBid);
      } catch (_) {
        currentItem = null;
      }
    }

    final currentBid = currentItem?.bid;
    final isGridMode = currentBid != null &&
        collectProvider.isGridLayoutBid(currentBid);
    
    final hasSelection = _selectedCollection != null && currentBid != null;
    final displayTitle = hasSelection && _hasActiveFilter ? '收藏 · 筛选中' : '收藏';

    List<Widget>? actions;
    if (currentBid != null) {
      actions = [
        // 排序按钮
        IconButton(
          tooltip: _sortOrder == null 
              ? '按时间排序' 
              : (_sortOrder == 'desc' ? '降序排列' : '升序排列'),
          icon: Icon(
            _sortOrder == null 
                ? Icons.sort 
                : (_sortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward),
            color: _sortOrder != null ? Colors.blue : Colors.white70,
            size: 20,
          ),
          onPressed: () => _toggleSortOrder(currentBid),
        ),
        IconButton(
          tooltip: isGridMode ? '切换列表模式' : '切换网格模式',
          icon: Icon(
            isGridMode ? Icons.list : Icons.grid_view,
            color: Colors.white70,
            size: 20,
          ),
          onPressed: () {
            final willBeGridMode = !isGridMode;
            context
                .read<CollectProvider>()
                .setGridLayoutForBid(currentBid, willBeGridMode);
            // 切换到网格模式时，如果数据量不足且还有更多数据，重新加载
            if (willBeGridMode && _hasMoreBlocks && _activeBlocks.length < 50) {
              setState(() {
                _activeBlocks = const [];
                _currentPage = 1;
                _hasMoreBlocks = true;
              });
              _fetchLinkBlocks(context: context, bid: currentBid, page: 1);
            }
          },
        ),
      ];
    }

    return SegmentedPageScaffold(
      title: displayTitle,
      segments: const ['块', '分组'],
      pages: [_buildBlockPage(isGridMode), _buildCollectionPage()],
      actions: actions,
      onTitleTap: hasSelection ? _showFilterDialog : null,
    );
  }

  Widget _buildCollectionPage() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildCollectionToolbar(context),
              const SizedBox(height: 22),
              Consumer<CollectProvider>(
                    builder: (_, provider, __) {
                      final entries = provider.entries;
                      if (entries.isEmpty) {
                        return const Text(
                      '暂无分组',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        );
                      }

                      if (!_isEditingOrder) {
                        return Column(
                          children: [
                            for (var index = 0; index < entries.length; index++)
                              Padding(
                                key: ValueKey(entries[index].id),
                            padding: EdgeInsets.only(
                              bottom: index == entries.length - 1 ? 0 : 24,
                            ),
                                child: CollectCollectionGroupWidget(
                                  entry: entries[index],
                                  isSelected: (item) =>
                                  _selectedCollection?.groupId ==
                                      entries[index].id &&
                                      _selectedCollection?.itemBid == item.bid,
                              onItemTap: (entryId, item) =>
                                  _handleCollectionTap(entryId, item),
                              onAdd: () =>
                                  _showAddItemDialog(context, entries[index]),
                              onDeleteItem: (item) => _handleDeleteItem(
                                context,
                                entries[index],
                                item,
                              ),
                              onHeaderOptions: () =>
                                  _showEntryOptions(context, entries[index]),
                                  isEditing: false,
                                ),
                              ),
                          ],
                        );
                      }

                      return ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: (oldIndex, newIndex) async {
                      await context.read<CollectProvider>().reorderEntries(
                        oldIndex,
                        newIndex,
                      );
                        },
                        itemCount: entries.length,
                        buildDefaultDragHandles: false,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Padding(
                            key: ValueKey(entry.id),
                        padding: EdgeInsets.only(
                          bottom: index == entries.length - 1 ? 0 : 24,
                        ),
                            child: CollectCollectionGroupWidget(
                              entry: entry,
                              isSelected: (item) =>
                                  _selectedCollection?.groupId == entry.id &&
                                  _selectedCollection?.itemBid == item.bid,
                          onItemTap: (entryId, item) =>
                              _handleCollectionTap(entryId, item),
                              onAdd: () => _showAddItemDialog(context, entry),
                          onDeleteItem: (item) =>
                              _handleDeleteItem(context, entry, item),
                          onHeaderOptions: () =>
                              _showEntryOptions(context, entry),
                              isEditing: true,
                              onReorderItems: (oldItemIndex, newItemIndex) async {
                            await context.read<CollectProvider>().reorderItems(
                              entry.id,
                              oldItemIndex,
                              newItemIndex,
                            );
                              },
                              dragIndex: index,
                            ),
                          );
                        },
                      );
                    },
              ),
            ]),
                  ),
                ),
              ],
    );
  }

  Widget _buildCollectionToolbar(BuildContext context) {
     final entryCount = context.select<CollectProvider, int>(
       (provider) => provider.entries.length,
     );
 
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分组',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '共 $entryCount 个',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _toggleEditingMode,
          icon: Icon(_isEditingOrder ? Icons.check : Icons.sort, size: 16),
          label: Text(_isEditingOrder ? '完成' : '排序'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _showAddEntryDialog(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('新增分组'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockPage(bool isGridMode) {
    final hasSelection = _selectedCollection != null;
    final blocks = _activeBlocks;

    Widget content;

    if (_isLoadingBlocks && hasSelection && blocks.isEmpty) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 32),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (!hasSelection) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 48),
          child: Text(
            '请选择左侧分组',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    } else if (!_isLoadingBlocks && blocks.isEmpty) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 48),
          child: Text(
            '暂无内容',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    } else {
      content = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!hasSelection || !_hasMoreBlocks || _isLoadingBlocks) {
            return false;
          }
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            _fetchLinkBlocks(
              context: context,
              bid: _selectedCollection!.itemBid,
              page: _currentPage + 1,
            );
          }
          return false;
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          // 网格模式下减少预加载区域，避免加载过多图片组件导致卡顿；列表模式保持全屏预加载以获得更好的滑动体验
          cacheExtent: isGridMode ? 200 : MediaQuery.of(context).size.height,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 15, 24, 32),
              sliver: isGridMode
                  ? SliverBlockGrid(blocks: blocks)
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final showLoader =
                              _isLoadingBlocks && index == blocks.length;

                          if (index >= blocks.length) {
                            if (showLoader) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == blocks.length - 1 ? 0 : 16,
                            ),
                          child: BlockCardFactory.build(blocks[index]),
                        );
                      },
                      childCount: blocks.length +
                          (_isLoadingBlocks && _hasMoreBlocks ? 1 : 0),
                      addAutomaticKeepAlives: false,
                    ),
                  ),
          ),
          if (isGridMode && _isLoadingBlocks && _hasMoreBlocks)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );

      final showFilterSummary = _hasActiveFilter || _isLoadingFilterData;
      if (showFilterSummary) {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: _isLoadingFilterData
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '筛选数据加载中…',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    )
                  : _buildFilterSummary(),
            ),
            Expanded(child: content),
          ],
        );
      }
    }

    // 添加拖拽区域包装
    final wrappedContent = _buildDropZone(child: content);

    // 添加FloatingActionButton
    return Stack(
      children: [
        wrappedContent,
        if (hasSelection)
          Positioned(
            right: 24,
            bottom: 24,
            child: _AddToLinkButton(
              isLoading: _isSubmitting,
              onTap: _isSubmitting ? null : () => _showAddToLinkDialog(),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterSummary() {
    if (!_hasActiveFilter) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];
    if (_modelFilter != null && _modelFilter!.isNotEmpty) {
      final label = _modelOptions[_modelFilter] ?? _modelFilter!;
      chips.add(_FilterSummaryChip(label: '模型: $label'));
    }
    if (_tagFilter != null && _tagFilter!.isNotEmpty) {
      chips.add(_FilterSummaryChip(label: '标签: $_tagFilter'));
    }

    return Row(
      children: [
        Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: chips)),
        TextButton(
          onPressed: _clearFilters,
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          child: const Text('清除'),
        ),
      ],
    );
  }

  Future<void> _handleRenameEntry(
    BuildContext context,
    CollectEntry entry,
  ) async {
    final controller = TextEditingController(text: entry.title);
    final updated = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AppDialog(
          title: '重命名分组',
          content: AppDialogTextField(
            controller: controller,
            label: '分组标题',
            hintText: '请输入新的分组标题',
          ),
          actions: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (updated == null || updated.isEmpty) {
      return;
    }

    await context.read<CollectProvider>().updateEntryTitle(entry.id, updated);
  }

  /// 构建拖拽区域
  Widget _buildDropZone({required Widget child}) {
    return DropTarget(
      onDragEntered: (details) {
        setState(() => _isDragging = true);
      },
      onDragExited: (details) {
        setState(() => _isDragging = false);
      },
      onDragDone: (details) {
        setState(() => _isDragging = false);
        _handleFileDrop(details.files);
      },
      child: Stack(
        children: [
          child,
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: Colors.blue.withValues(alpha: 0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_upload,
                          size: 64,
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '拖放文件到这里上传',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          '正在上传文件...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 处理文件拖拽
  Future<void> _handleFileDrop(List<XFile> files) async {
    if (files.isEmpty) return;

    final bid = _selectedCollection?.itemBid;
    if (bid == null || bid.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择一个收藏')),
        );
      }
      return;
    }

    // 检查当前页面是否是路由栈顶部的页面（即当前可见的页面）
    // 这样可以防止导航栈中的其他 CollectPage 实例也处理拖拽事件
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) {
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 直接使用当前选中节点的 BID
      final connectionProvider = context.read<ConnectionProvider>();
      final nodeBid = connectionProvider.activeNodeData?['sender'] as String?;

      if (nodeBid == null || nodeBid.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未连接到节点，无法上传文件')),
          );
        }
        return;
      }

      final uploadService = FileUploadService(
        connectionProvider: connectionProvider,
      );

      int successCount = 0;
      int failCount = 0;

      for (final xFile in files) {
        try {
          final file = File(xFile.path);
          final block = await uploadService.uploadFile(
            file: file,
            linkBid: bid,
            nodeBid: nodeBid,
            encrypt: true,
          );

          // 更新 BlockProvider
          if (mounted) {
            context.read<BlockProvider>().updateBlock(block);
          }

          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      if (!mounted) return;

      // 刷新列表
      if (_selectedCollection != null) {
        await _fetchLinkBlocks(
          context: context,
          bid: _selectedCollection!.itemBid,
          page: 1,
        );
      }

      // 显示结果
      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failCount > 0
                  ? '成功上传 $successCount 个文件，失败 $failCount 个'
                  : '成功上传 $successCount 个文件',
            ),
          ),
        );
      } else if (failCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件上传失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}

class _CollectSelection {
  const _CollectSelection({required this.groupId, required this.itemBid});

  final String groupId;
  final String itemBid;
}

enum _EntryAction { rename, delete }

class _EntryEditorDialog extends StatefulWidget {
  const _EntryEditorDialog({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_EntryEditorDialog> createState() => _EntryEditorDialogState();
}

class _EntryEditorDialogState extends State<_EntryEditorDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '新增分组',
      content: Form(
        key: _formKey,
        child: AppDialogTextField(
          controller: _controller,
          label: '分组名称',
          hintText: '例如：设计资料库',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入分组名称';
            }
            return null;
          },
        ),
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
                foregroundColor: Colors.white70,
              ),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) {
                        return;
                      }
                      setState(() => _isSubmitting = true);
                      widget.onSubmit(_controller.text.trim());
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemEditorDialog extends StatefulWidget {
  const _ItemEditorDialog({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  final _bidController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '新增分组条目',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogTextField(
              controller: _bidController,
              label: '条目 BID',
              hintText: '32位块 ID',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入条目 BID';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
                foregroundColor: Colors.white70,
              ),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) {
                        return;
                      }
                      setState(() => _isSubmitting = true);
                      widget.onSubmit(_bidController.text.trim());
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSummaryChip extends StatelessWidget {
  const _FilterSummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _AddToLinkButton extends StatelessWidget {
  const _AddToLinkButton({
    required this.isLoading,
    required this.onTap,
  });

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isLoading && onTap != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 0.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : Icon(
                    Icons.add,
                    color: isEnabled ? Colors.white : Colors.white38,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}
