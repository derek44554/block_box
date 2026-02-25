import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:block_app/core/network/api/block_api.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';

import '../../../components/layout/collection_picker_sheet.dart';
import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/widgets/layouts/segmented_page_scaffold.dart';
import '../../../state/connection_provider.dart';
import '../../../state/block_provider.dart';
import '../../collect/providers/collect_provider.dart';
import '../widgets/add_link_dialog.dart';
import '../widgets/link_block_list.dart';
import '../services/file_upload_service.dart';

/// LinkPage 负责展示 BID 相关的关联块与外链块列表，通过网络请求实时获取数据。
class LinkPage extends StatefulWidget {
  final String? bid;
  final int initialIndex;

  const LinkPage({super.key, this.bid, this.initialIndex = 0});

  @override
  State<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends State<LinkPage> {
  final List<BlockModel> _linkBlocks = [];
  final List<BlockModel> _externalBlocks = [];
  List<String> _availableLinkTags = const <String>[];
  bool _isLoadingLinks = false;
  bool _isLoadingExternal = false;
  bool _isLoadingMoreLinks = false;
  bool _isLoadingMoreExternal = false;
  bool _isLoadingFilterData = false;
  bool _hasLoadedFilterData = false;
  bool _hasMoreLinks = true;
  bool _hasMoreExternal = true;
  int _linkPage = 1;
  int _externalPage = 1;
  String? _linkError;
  String? _externalError;
  bool _isSubmitting = false;
  String? _modelFilter;
  String? _tagFilter;
  bool _useGridLayout = false;
  int _currentTabIndex = 0;
  static const int _pageSize = 20;
  bool _isDragging = false;
  bool _isUploading = false;

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
    _currentTabIndex = widget.initialIndex;
    if (widget.bid != null && widget.bid!.trim().isNotEmpty) {
      _fetchLinkTargets();
      _fetchLinkMains();
      _loadAvailableLinkTags();
    }
    
    // Listen to BlockProvider for Block updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BlockProvider>().addListener(_onBlockProviderUpdate);
      }
    });
  }

  @override
  void dispose() {
    // Remove BlockProvider listener
    context.read<BlockProvider>().removeListener(_onBlockProviderUpdate);
    super.dispose();
  }

  /// Handle BlockProvider updates
  /// 
  /// When BlockProvider notifies of a Block update, check if the updated Block
  /// exists in our local lists (_linkBlocks or _externalBlocks) and update it.
  void _onBlockProviderUpdate() {
    if (!mounted) return;
    
    final blockProvider = context.read<BlockProvider>();
    bool hasUpdates = false;
    
    // Update _linkBlocks if any Block in the list was updated
    for (int i = 0; i < _linkBlocks.length; i++) {
      final bid = _linkBlocks[i].maybeString('bid');
      if (bid != null) {
        final updatedBlock = blockProvider.getBlock(bid);
        if (updatedBlock != null) {
          _linkBlocks[i] = updatedBlock;
          hasUpdates = true;
        }
      }
    }
    
    // Update _externalBlocks if any Block in the list was updated
    for (int i = 0; i < _externalBlocks.length; i++) {
      final bid = _externalBlocks[i].maybeString('bid');
      if (bid != null) {
        final updatedBlock = blockProvider.getBlock(bid);
        if (updatedBlock != null) {
          _externalBlocks[i] = updatedBlock;
          hasUpdates = true;
        }
      }
    }
    
    // Trigger UI update if any Block was updated
    if (hasUpdates) {
      setState(() {});
    }
  }

  Future<void> _fetchLinkTargets({bool loadMore = false}) async {
    final bid = widget.bid;
    if (bid == null || bid.trim().isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }
    if (loadMore) {
      if (_isLoadingMoreLinks || !_hasMoreLinks) {
        return;
      }
      setState(() {
        _isLoadingMoreLinks = true;
      });
    } else {
      setState(() {
        _isLoadingLinks = true;
        _linkError = null;
        _hasMoreLinks = true;
        _linkPage = 1;
      });
    }

    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final targetPage = loadMore ? _linkPage + 1 : 1;
      final response = await api.getLinksByTarget(
        bid: bid,
        page: targetPage,
        limit: _pageSize,
      );
      final data = response['data'];
      final blocks = _extractBlocksFromResponse(data);
      if (!mounted) {
        return;
      }
      setState(() {
        if (targetPage == 1) {
          _linkBlocks
            ..clear()
            ..addAll(blocks);
        } else {
          for (final block in blocks) {
            final bid = block.maybeString('bid');
            final exists = _linkBlocks.any(
              (item) => item.maybeString('bid') == bid,
            );
            if (!exists) {
              _linkBlocks.add(block);
            }
          }
        }
        _linkPage = targetPage;
        _hasMoreLinks = blocks.length >= _pageSize;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _linkError = _normalizeError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLinks = false;
          _isLoadingMoreLinks = false;
        });
      }
    }
  }

  Future<void> _fetchLinkMains({bool loadMore = false}) async {
    final bid = widget.bid;
    if (bid == null || bid.trim().isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }
    if (loadMore) {
      if (_isLoadingMoreExternal || !_hasMoreExternal) {
        return;
      }
      setState(() {
        _isLoadingMoreExternal = true;
      });
    } else {
      setState(() {
        _isLoadingExternal = true;
        _externalError = null;
        _hasMoreExternal = true;
        _externalPage = 1;
      });
    }

    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final targetPage = loadMore ? _externalPage + 1 : 1;
      final response = await api.getLinksByMain(
        bid: bid,
        page: targetPage,
        limit: _pageSize,
        model: _modelFilter,
        tag: _tagFilter,
      );
      final data = response['data'];
      final blocks = _extractBlocksFromResponse(data);
      if (!mounted) {
        return;
      }
      setState(() {
        if (targetPage == 1) {
          _externalBlocks
            ..clear()
            ..addAll(blocks);
        } else {
          for (final block in blocks) {
            final bid = block.maybeString('bid');
            final exists = _externalBlocks.any(
              (item) => item.maybeString('bid') == bid,
            );
            if (!exists) {
              _externalBlocks.add(block);
            }
          }
        }
        _externalPage = targetPage;
        _hasMoreExternal = blocks.length >= _pageSize;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _externalError = _normalizeError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExternal = false;
          _isLoadingMoreExternal = false;
        });
      }
    }
  }

  List<BlockModel> _extractBlocksFromResponse(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return const <BlockModel>[];
    }

    final items = payload['items'];
    if (items is! List) {
      return const <BlockModel>[];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => BlockModel(data: item))
        .toList();
  }

  String _normalizeError(Object error) {
    final message = error.toString();
    if (message.isEmpty) {
      return '加载失败，请稍后重试';
    }
    return message;
  }

  Future<void> _loadAvailableLinkTags() async {
    if (_hasLoadedFilterData) {
      return;
    }
    final bid = widget.bid;
    if (bid == null || bid.trim().isEmpty) {
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
    if (widget.bid == null || widget.bid!.trim().isEmpty) {
      return;
    }

    if (!_hasLoadedFilterData && !_isLoadingFilterData) {
      await _loadAvailableLinkTags();
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
              title: '筛选外链',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
    });
    _fetchLinkMains();
  }

  void _clearFilters() {
    if (!_hasActiveFilter) {
      return;
    }
    setState(() {
      _modelFilter = null;
      _tagFilter = null;
    });
    _fetchLinkMains();
  }

  Widget _buildLinkTargetsTab(bool useGridLayout) {
    return _buildDropZone(
      child: LinkBlockList(
        isLoading: _isLoadingLinks,
        error: _linkError,
        blocks: _linkBlocks,
        onRetry: _fetchLinkTargets,
        isLoadingMore: _isLoadingMoreLinks,
        hasMore: _hasMoreLinks,
        onLoadMore: () => _fetchLinkTargets(loadMore: true),
        useGridLayout: useGridLayout,
        onBlockLongPress: _handleBlockLongPress,
      ),
    );
  }

  Widget _buildExternalTab(bool useGridLayout) {
    final list = LinkBlockList(
      isLoading: _isLoadingExternal,
      error: _externalError,
      blocks: _externalBlocks,
      onRetry: _fetchLinkMains,
      isLoadingMore: _isLoadingMoreExternal,
      hasMore: _hasMoreExternal,
      onLoadMore: () => _fetchLinkMains(loadMore: true),
      useGridLayout: useGridLayout,
      onBlockLongPress: _handleBlockLongPress,
    );

    final showSummary = _hasActiveFilter || _isLoadingFilterData;
    if (!showSummary) {
      return _buildDropZone(child: list);
    }

    return _buildDropZone(
      child: Column(
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
          Expanded(child: list),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final bidText = widget.bid != null ? formatBid(widget.bid!) : '链接';
    final displayTitle = _hasActiveFilter ? '$bidText · 筛选中' : bidText;
    final hasBid = widget.bid != null && widget.bid!.trim().isNotEmpty;
    final useGridLayout = hasBid
        ? context.watch<CollectProvider>().isGridLayoutBid(widget.bid!)
        : _useGridLayout;
    return SegmentedPageScaffold(
      title: displayTitle,
      initialIndex: widget.initialIndex,
      segments: const ['链接', '外链'],
      onTitleTap: widget.bid == null ? null : _showFilterDialog,
      onIndexChanged: (index) {
        setState(() => _currentTabIndex = index);
      },
      pages: [
        _buildLinkTargetsTab(useGridLayout),
        _buildExternalTab(useGridLayout),
      ],
      controlWidth: 120,
      actions: _buildHeaderActions(useGridLayout, hasBid),
      floatingActionButton: widget.bid == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 20),
              child: _MiniIconButton(
                isLoading: _isSubmitting,
                onTap: _isSubmitting ? null : _handleAddLink,
                icon: Icons.add,
              ),
            ),
    );
  }

  Future<void> _handleAddLink() async {
    final bid = widget.bid;
    if (bid == null || bid.trim().isEmpty) {
      return;
    }

    // 判断当前在哪个标签页：0=链接，1=外链
    final isExternalTab = _currentTabIndex == 1;

    final newBid = await showAddLinkDialog(context);

    if (newBid == null || newBid.trim().isEmpty) {
      return;
    }

    final trimmedBid = newBid.trim();

    if (isExternalTab) {
      // 外链页面：将当前BID添加到对方块的link列表中
      await _handleAddExternalLink(bid, trimmedBid);
    } else {
      // 链接页面：将对方BID添加到当前块的link列表中
      await _handleAddNormalLink(bid, trimmedBid);
    }
  }

  Future<void> _handleAddNormalLink(String currentBid, String targetBid) async {
    final existing = _linkBlocks.any(
      (block) => block.maybeString('bid') == targetBid,
    );
    if (existing) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该 BID 已存在链接列表中')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);

      final fetched = await api.getBlock(bid: targetBid);
      final data = fetched['data'];
      if (data == null || data is! Map<String, dynamic> || data.isEmpty) {
        throw Exception('未找到指定 BID 对应的块');
      }

      final currentBlockResponse = await api.getBlock(bid: currentBid);
      final currentData = currentBlockResponse['data'];
      if (currentData == null || currentData is! Map<String, dynamic>) {
        throw Exception('无法获取当前块信息');
      }

      final updatedData = Map<String, dynamic>.from(currentData);
      final links = (updatedData['link'] is List
          ? List<String>.from(updatedData['link'])
          : <String>[]);

      if (links.contains(targetBid)) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该 BID 已存在链接列表中')));
        return;
      }

      links.add(targetBid);
      updatedData['link'] = links;
      updatedData['bid'] = currentBid;

      await api.saveBlock(data: updatedData);

      await _fetchLinkTargets();
      await _fetchLinkMains();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加链接')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleAddExternalLink(String currentBid, String targetBid) async {
    final existing = _externalBlocks.any(
      (block) => block.maybeString('bid') == targetBid,
    );
    if (existing) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该 BID 已存在外链列表中')));
      return;
    }

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

      // 修改目标块，将当前BID添加到目标块的link列表中
      final updatedData = Map<String, dynamic>.from(targetData);
      final links = (updatedData['link'] is List
          ? List<String>.from(updatedData['link'])
          : <String>[]);

      if (links.contains(currentBid)) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该 BID 已存在对方的链接列表中')));
        return;
      }

      links.add(currentBid);
      updatedData['link'] = links;
      updatedData['bid'] = targetBid;

      // 提交对方块的修改请求
      await api.saveBlock(data: updatedData);

      await _fetchLinkTargets();
      await _fetchLinkMains();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加外链')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleBlockLongPress(BlockModel block) async {
    final targetBid = block.maybeString('bid');
    if (targetBid == null || targetBid.isEmpty) {
      return;
    }

    final currentBid = widget.bid;
    if (currentBid == null || currentBid.isEmpty) {
      return;
    }

    // 判断当前在哪个标签页：0=链接，1=外链
    final isExternalTab = _currentTabIndex == 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppDialog(
          title: '移除链接',
          content: Text(
            isExternalTab
                ? '确定要从对方的链接列表中移除当前块吗？'
                : '确定要移除该链接吗？',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                child: const Text('移除'),
              ),
            ],
          ),
        );
      },
    );

    if (result != true || !mounted) {
      return;
    }

    if (isExternalTab) {
      // 外链页面：从目标块的link列表中移除当前BID
      await _removeExternalLink(currentBid, targetBid);
    } else {
      // 链接页面：从当前块的link列表中移除目标BID
      await _removeNormalLink(currentBid, targetBid);
    }
  }

  Future<void> _removeNormalLink(String currentBid, String targetBid) async {
    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);

      // 获取当前块的信息
      final currentBlockResponse = await api.getBlock(bid: currentBid);
      final currentData = currentBlockResponse['data'];
      if (currentData == null || currentData is! Map<String, dynamic>) {
        throw Exception('无法获取当前块信息');
      }

      // 从link列表中移除目标BID
      final updatedData = Map<String, dynamic>.from(currentData);
      final links = (updatedData['link'] is List
          ? List<String>.from(updatedData['link'])
          : <String>[]);

      if (!links.contains(targetBid)) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该 BID 不在链接列表中')));
        return;
      }

      links.remove(targetBid);
      updatedData['link'] = links;
      updatedData['bid'] = currentBid;

      await api.saveBlock(data: updatedData);

      await _fetchLinkTargets();
      await _fetchLinkMains();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已移除链接')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('移除失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _removeExternalLink(String currentBid, String targetBid) async {
    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);

      // 获取目标块的信息
      final targetBlockResponse = await api.getBlock(bid: targetBid);
      final targetData = targetBlockResponse['data'];
      if (targetData == null || targetData is! Map<String, dynamic>) {
        throw Exception('无法获取目标块信息');
      }

      // 从目标块的link列表中移除当前BID
      final updatedData = Map<String, dynamic>.from(targetData);
      final links = (updatedData['link'] is List
          ? List<String>.from(updatedData['link'])
          : <String>[]);

      if (!links.contains(currentBid)) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前 BID 不在对方的链接列表中')));
        return;
      }

      links.remove(currentBid);
      updatedData['link'] = links;
      updatedData['bid'] = targetBid;

      // 提交对方块的修改请求
      await api.saveBlock(data: updatedData);

      await _fetchLinkTargets();
      await _fetchLinkMains();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已移除外链')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('移除失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  List<Widget>? _buildHeaderActions(bool useGridLayout, bool canPersist) {
    final icon =
        useGridLayout ? Icons.view_list_outlined : Icons.grid_view_outlined;
    final tooltip = useGridLayout ? '切换为列表视图' : '切换为网格视图';
    return [
      Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: () async {
            if (canPersist && widget.bid != null) {
              await context
                  .read<CollectProvider>()
                  .setGridLayoutForBid(widget.bid!, !useGridLayout);
            } else {
              setState(() => _useGridLayout = !useGridLayout);
            }
          },
          icon: Icon(icon, color: Colors.white),
          splashRadius: 18,
        ),
      ),
    ];
  }

  /// 构建拖拽区域
  Widget _buildDropZone({required Widget child}) {
    if (widget.bid == null || widget.bid!.trim().isEmpty) {
      return child;
    }

    return DropTarget(
      onDragEntered: (_) {
        setState(() => _isDragging = true);
      },
      onDragExited: (_) {
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
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.upload_file,
                          size: 64,
                          color: Colors.blue,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '释放以上传文件',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '文件将自动关联到此收藏',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
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

    final bid = widget.bid;
    if (bid == null || bid.trim().isEmpty) return;

    // 检查当前页面是否是路由栈顶部的页面（即当前可见的页面）
    // 这样可以防止导航栈中的其他 LinkPage 实例也处理拖拽事件
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
      final api = BlockApi(connectionProvider: connectionProvider);

      int successCount = 0;
      int failCount = 0;
      final isLinkTab = _currentTabIndex == 0; // 是否在"链接"标签

      for (final xFile in files) {
        try {
          final file = File(xFile.path);
          
          // 根据当前标签决定 linkBid
          // 链接标签(0): 不设置 linkBid，后续手动添加到目标 Block
          // 外链标签(1): 设置 linkBid 为目标 BID
          final block = await uploadService.uploadFile(
            file: file,
            linkBid: isLinkTab ? null : bid,
            nodeBid: nodeBid,
            encrypt: true,
          );

          // 如果在"链接"标签，需要将新 Block 的 BID 添加到目标 Block 的 link 中
          if (isLinkTab) {
            final newBlockBid = block.data['bid'] as String?;
            
            if (newBlockBid != null && newBlockBid.isNotEmpty) {
              // 获取目标 Block
              final targetResponse = await api.getBlock(bid: bid);
              final targetData = targetResponse['data'];
              
              if (targetData is Map<String, dynamic>) {
                final updatedData = Map<String, dynamic>.from(targetData);
                final links = List<String>.from(updatedData['link'] ?? []);
                
                // 添加新 Block 的 BID
                if (!links.contains(newBlockBid)) {
                  links.add(newBlockBid);
                  updatedData['link'] = links;
                  
                  // 保存更新后的目标 Block
                  await api.saveBlock(data: updatedData);
                  
                  // 更新 BlockProvider
                  if (mounted) {
                    context.read<BlockProvider>().updateBlock(BlockModel(data: updatedData));
                  }
                }
              }
            }
          }

          // 更新新创建的 Block 到 BlockProvider
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
      await _fetchLinkTargets();
      await _fetchLinkMains();

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

class _AddLinkDialogBody extends StatelessWidget {
  const _AddLinkDialogBody({required this.controller});
 
   final TextEditingController controller;
 
   @override
   Widget build(BuildContext context) {
     return Column(
       mainAxisSize: MainAxisSize.min,
       crossAxisAlignment: CrossAxisAlignment.stretch,
       children: [
        AppDialogTextField(
          controller: controller,
          label: '链接 BID',
          hintText: '请输入链接的 BID',
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            final bid = await CollectionPickerSheet.show(context);
            if (bid != null && bid.isNotEmpty) {
              controller.text = bid;
              if (context.mounted) {
                Navigator.of(context).pop(bid);
              }
            }
          },
          icon: const Icon(
            Icons.collections_bookmark_outlined,
            color: Colors.white70,
            size: 18,
          ),
          label: const Text(
            '更多集合',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white24, width: 0.6),
            foregroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.isLoading,
    required this.onTap,
    required this.icon,
  });

  final bool isLoading;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isLoading && onTap != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            spreadRadius: 0.5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isEnabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : Icon(
                    icon,
                    color: isEnabled ? Colors.white : Colors.white38,
                    size: 18,
                  ),
          ),
        ),
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
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.7),
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
