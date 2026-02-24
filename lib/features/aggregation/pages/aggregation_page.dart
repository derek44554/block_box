import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:block_app/core/network/api/block_api.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';
import 'package:block_app/core/widgets/dialogs/confirmation_dialog.dart';

import '../../../components/block/block_card_factory.dart';
import '../../../components/block/block_grid_layout.dart';
import '../../../core/models/block_model.dart';
import '../../../core/widgets/common/action_sheet.dart';
import '../../../core/widgets/common/tag_name_dialog.dart';
import '../../../core/widgets/layouts/segmented_page_scaffold.dart';
import '../../../state/connection_provider.dart';
import '../models/aggregation_models.dart';
import '../providers/aggregation_provider.dart';


class AggregationPage extends StatefulWidget {
  const AggregationPage({super.key});

  @override
  State<AggregationPage> createState() => _AggregationPageState();
}

class _AggregationPageState extends State<AggregationPage> {
  List<BlockModel> _activeBlocks = const [];
  String? _selectedItemId;
  String? _selectedTag;
  bool _isEditingOrder = false;
  bool _isLoadingBlocks = false;
  int _currentPage = 1;
  String? _activeRequestKey;
  bool _hasMoreBlocks = true;
  bool _selectionRestored = false;
  VoidCallback? _providerListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AggregationProvider>();
      if (provider.items.isNotEmpty && !_selectionRestored) {
        _restoreSelection(provider);
      } else if (!_selectionRestored) {
        // 如果数据还没加载，添加监听器等待数据加载
        _providerListener = () {
          final items = provider.items;
          if (items.isNotEmpty && !_selectionRestored) {
            _restoreSelection(provider);
            provider.removeListener(_providerListener!);
            _providerListener = null;
          }
        };
        provider.addListener(_providerListener!);
      }
    });
  }

  @override
  void dispose() {
    if (_providerListener != null) {
      context.read<AggregationProvider>().removeListener(_providerListener!);
      _providerListener = null;
    }
    super.dispose();
  }

  void _restoreSelection(AggregationProvider provider) {
    final selectedId = provider.selectedItemId;
    
    if (selectedId == null) {
      return;
    }

    // 查找选中的项
    final selectedItem = provider.items
        .where((item) => item.id == selectedId)
        .firstOrNull;

    if (selectedItem == null) {
      return;
    }

    setState(() {
      _selectedItemId = selectedId;
      _activeBlocks = const [];
      _hasMoreBlocks = true;
      _currentPage = 1;
      _selectionRestored = true;
    });

    // 自动加载该项的块
    _fetchBlocksByModel(context: context, model: selectedItem.model, page: 1, tag: null);
  }

  void _handleItemTap(AggregationItem item) {
    setState(() {
      if (_selectedItemId == item.id) {
        _selectedItemId = null;
        _selectedTag = null;
        context.read<AggregationProvider>().setSelectedItem(null);
      } else {
        _selectedItemId = item.id;
        _selectedTag = null;
        _activeBlocks = const [];
        _hasMoreBlocks = true;
        _currentPage = 1;
        context.read<AggregationProvider>().setSelectedItem(item.id);
      }
    });

    if (_selectedItemId != null) {
      _fetchBlocksByModel(context: context, model: item.model, page: 1, tag: null);
    } else {
      setState(() {
        _activeBlocks = const [];
      });
    }
  }

  void _handleTagTap(AggregationItem item, String tag) {
    setState(() {
      if (_selectedItemId == item.id && _selectedTag == tag) {
        // 取消选中标签
        _selectedTag = null;
      } else {
        // 选中新标签
        _selectedItemId = item.id;
        _selectedTag = tag;
        context.read<AggregationProvider>().setSelectedItem(item.id);
      }
      _activeBlocks = const [];
      _hasMoreBlocks = true;
      _currentPage = 1;
    });

    _fetchBlocksByModel(
      context: context,
      model: item.model,
      page: 1,
      tag: _selectedTag,
    );
  }

  void _toggleEditingMode() {
    setState(() {
      _isEditingOrder = !_isEditingOrder;
    });
  }

  Future<void> _fetchBlocksByModel({
    required BuildContext context,
    required String model,
    required int page,
    String? tag,
  }) async {
    if (_isLoadingBlocks) {
      return;
    }

    final requestKey = 'model#$model#$page#${tag ?? ""}';
    _activeRequestKey = requestKey;
    setState(() {
      _isLoadingBlocks = true;
    });

    try {
      // 根据网格模式调整分页大小
      final selectedItemId = _selectedItemId;
      final isGridMode = selectedItemId != null &&
          context.read<AggregationProvider>().isGridLayoutItem(selectedItemId);
      final pageLimit = isGridMode ? 50 : 20;

      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final response = await api.getAllBlocks(
        model: model,
        page: page,
        limit: pageLimit,
        tag: tag,
      );
      debugPrint('Model blocks response for "$model" (page $page, tag: $tag): $response');

      if (!mounted || _activeRequestKey != requestKey) {
        return;
      }

      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('块请求返回数据格式无效');
      }

      final items = data['items'];
      if (items is! List) {
        throw Exception('块请求 items 数据格式无效');
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

        final total = data['count'];
        if (total is int) {
          _hasMoreBlocks = _activeBlocks.length < total;
          // 更新项的数量
          if (_selectedItemId != null) {
            context.read<AggregationProvider>().updateItemCount(_selectedItemId!, total);
          }
        } else {
          _hasMoreBlocks = fetchedBlocks.isNotEmpty;
        }
      });
    } catch (error, stack) {
      debugPrint('Failed to fetch blocks for model $model: $error');
      debugPrint('$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载块失败：${error.toString()}'),
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

  void _showAddItemDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _ItemEditorDialog(
        onSubmit: (title, model) =>
            context.read<AggregationProvider>().addItem(title, model),
      ),
    );
  }

  Future<void> _handleDeleteItem(
    BuildContext context,
    AggregationItem item,
  ) async {
    final confirm = await showConfirmationDialog(
      context: context,
      title: '确认删除项？',
      content: Text(
        '项 "${item.title}" 删除后不可恢复，是否继续？',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      confirmText: '删除',
      isDestructive: true,
    );

    if (confirm == true) {
      context.read<AggregationProvider>().removeItem(item.id);
    }
  }

  Future<void> _showItemOptions(
    BuildContext context,
    AggregationItem item,
  ) async {
    final action = await showModalBottomSheet<_ItemAction>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return ActionSheet(
          title: '项选项',
          actions: [
            ActionItem(
              label: '重命名',
              icon: Icons.edit_outlined,
              onTap: () => Navigator.of(context).pop(_ItemAction.rename),
            ),
            ActionItem(
              label: '修改Model',
              icon: Icons.category_outlined,
              onTap: () => Navigator.of(context).pop(_ItemAction.changeModel),
            ),
            ActionItem(
              label: '添加标签',
              icon: Icons.label_outline,
              onTap: () => Navigator.of(context).pop(_ItemAction.manageTags),
            ),
            ActionItem(
              label: '删除',
              icon: Icons.delete_outline,
              isDestructive: true,
              onTap: () => Navigator.of(context).pop(_ItemAction.delete),
            ),
          ],
        );
      },
    );

    switch (action) {
      case _ItemAction.rename:
        await _handleRenameItem(context, item);
        break;
      case _ItemAction.changeModel:
        await _handleChangeModel(context, item);
        break;
      case _ItemAction.manageTags:
        await _handleManageTags(context, item);
        break;
      case _ItemAction.delete:
        await _handleDeleteItem(context, item);
        break;
      case null:
        break;
    }
  }

  Future<void> _handleManageTags(
    BuildContext context,
    AggregationItem item,
  ) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => TagNameDialog(
        title: '新增标签',
        description: '标签用于筛选该项下的块，可随时删除或重新选择。',
        label: '标签名称',
        hintText: '请输入标签名称',
        validator: (value) {
          final trimmed = value?.trim() ?? '';
          if (trimmed.isEmpty) {
            return '请输入标签名称';
          }
          if (item.tags.contains(trimmed)) {
            return '标签已存在';
          }
          if (trimmed.length > 24) {
            return '标签长度请控制在 24 个字符以内';
          }
          return null;
        },
      ),
    );

    final trimmed = result?.trim() ?? '';
    if (trimmed.isEmpty) {
      return;
    }

    context.read<AggregationProvider>().addTagToItem(item.id, trimmed);
  }

  void _showTagOptions(AggregationItem item, String tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111114),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white),
                title: const Text(
                  '删除标签',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  this.context.read<AggregationProvider>().removeTagFromItem(item.id, tag);
                  // 如果当前选中了这个标签，取消选中
                  if (_selectedTag == tag) {
                    setState(() {
                      _selectedTag = null;
                      _activeBlocks = const [];
                      _currentPage = 1;
                      _hasMoreBlocks = true;
                    });
                    _fetchBlocksByModel(
                      context: this.context,
                      model: item.model,
                      page: 1,
                      tag: null,
                    );
                  }
                },
              ),
              const Divider(height: 0, color: Color(0x22FFFFFF)),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white54),
                title: const Text(
                  '取消',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRenameItem(
    BuildContext context,
    AggregationItem item,
  ) async {
    final controller = TextEditingController(text: item.title);
    final updated = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AppDialog(
          title: '重命名项',
          content: AppDialogTextField(
            controller: controller,
            label: '项名称',
            hintText: '请输入新的项名称',
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

    context.read<AggregationProvider>().updateItemTitle(item.id, updated);
  }

  Future<void> _handleChangeModel(
    BuildContext context,
    AggregationItem item,
  ) async {
    final newModel = await showDialog<String?>(
      context: context,
      builder: (context) => _ModelSelectorDialog(currentModel: item.model),
    );

    if (newModel == null || newModel == item.model) {
      return;
    }

    context.read<AggregationProvider>().updateItemModel(item.id, newModel);
    
    // 如果当前选中的是这个项，重新加载数据
    if (_selectedItemId == item.id) {
      setState(() {
        _activeBlocks = const [];
        _currentPage = 1;
        _hasMoreBlocks = true;
        _selectedTag = null;
      });
      _fetchBlocksByModel(context: context, model: newModel, page: 1, tag: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aggregationProvider = context.watch<AggregationProvider>();
    final currentItemId = _selectedItemId;
    final isGridMode = currentItemId != null &&
        aggregationProvider.isGridLayoutItem(currentItemId);

    List<Widget>? actions;
    if (currentItemId != null) {
      actions = [
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
                .read<AggregationProvider>()
                .setGridLayoutForItem(currentItemId, willBeGridMode);
            // 切换到网格模式时，如果数据量不足且还有更多数据，重新加载
            if (willBeGridMode && _hasMoreBlocks && _activeBlocks.length < 50) {
              setState(() {
                _activeBlocks = const [];
                _currentPage = 1;
                _hasMoreBlocks = true;
              });
              final selectedItem = aggregationProvider.items
                  .where((item) => item.id == currentItemId)
                  .firstOrNull;
              if (selectedItem != null) {
                _fetchBlocksByModel(
                  context: context,
                  model: selectedItem.model,
                  page: 1,
                  tag: _selectedTag,
                );
              }
            }
          },
        ),
      ];
    }

    return SegmentedPageScaffold(
      title: '聚集',
      segments: const ['块', '项'],
      pages: [_buildBlockPage(isGridMode), _buildItemsPage()],
      actions: actions,
    );
  }

  Widget _buildItemsPage() {
    return Row(
      children: [
        // 左侧：项列表（固定宽度）
        SizedBox(
          width: 250,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 15, 24, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildItemsToolbar(context),
                      const SizedBox(height: 12),
                      Consumer<AggregationProvider>(
                        builder: (_, provider, __) {
                          final items = provider.items;
                          if (items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 32),
                              child: Center(
                                child: Text(
                                  '暂无项',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ),
                            );
                          }

                          if (!_isEditingOrder) {
                            return Column(
                              children: [
                                for (var index = 0; index < items.length; index++)
                                  Padding(
                                    key: ValueKey(items[index].id),
                                    padding: EdgeInsets.only(
                                      bottom: index == items.length - 1 ? 0 : 12,
                                    ),
                                    child: _AggregationItemSimpleCard(
                                      item: items[index],
                                      isSelected: _selectedItemId == items[index].id,
                                      onTap: () => _handleItemSelect(items[index]),
                                      onOptions: () => _showItemOptions(context, items[index]),
                                    ),
                                  ),
                              ],
                            );
                          }

                          return ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            onReorder: (oldIndex, newIndex) {
                              context.read<AggregationProvider>().reorderItems(
                                    oldIndex,
                                    newIndex,
                                  );
                            },
                            itemCount: items.length,
                            buildDefaultDragHandles: false,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Padding(
                                key: ValueKey(item.id),
                                padding: EdgeInsets.only(
                                  bottom: index == items.length - 1 ? 0 : 12,
                                ),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: const Icon(
                                          Icons.drag_handle,
                                          color: Colors.white38,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _AggregationItemSimpleCard(
                                        item: item,
                                        isSelected: _selectedItemId == item.id,
                                        onTap: () => _handleItemSelect(item),
                                        onOptions: () => _showItemOptions(context, item),
                                      ),
                                    ),
                                  ],
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
            ),
          ),
        ),
        // 右侧：标签列表（占据剩余空间）
        Expanded(
          child: _buildTagsPanel(),
        ),
      ],
    );
  }

  void _handleItemSelect(AggregationItem item) {
    setState(() {
      if (_selectedItemId == item.id) {
        _selectedItemId = null;
        _selectedTag = null;
        context.read<AggregationProvider>().setSelectedItem(null);
        _activeBlocks = const [];
      } else {
        _selectedItemId = item.id;
        _selectedTag = null;
        _activeBlocks = const [];
        _hasMoreBlocks = true;
        _currentPage = 1;
        context.read<AggregationProvider>().setSelectedItem(item.id);
      }
    });

    // 选中项时，自动加载该model类型的所有块
    if (_selectedItemId != null) {
      _fetchBlocksByModel(context: context, model: item.model, page: 1, tag: null);
    }
  }

  Widget _buildTagsPanel() {
    return Consumer<AggregationProvider>(
      builder: (context, provider, _) {
        if (_selectedItemId == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                '请选择左侧的项',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          );
        }

        final selectedItem = provider.items
            .where((item) => item.id == _selectedItemId)
            .firstOrNull;

        if (selectedItem == null) {
          return const Center(
            child: Text(
              '未找到选中的项',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 15, 24, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => _handleManageTags(context, selectedItem),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('添加标签'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (selectedItem.tags.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          '暂无标签',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: selectedItem.tags
                          .map(
                            (tag) => _GroupTagItem(
                              label: tag,
                              isActive: _selectedTag == tag,
                              onTap: () => _handleTagTap(selectedItem, tag),
                              onLongPress: () => _showTagOptions(selectedItem, tag),
                            ),
                          )
                          .toList(),
                    ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemsToolbar(BuildContext context) {
    return Row(
      children: [
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
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => _showAddItemDialog(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('新增项'),
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
    final hasSelection = _selectedItemId != null;
    final blocks = _activeBlocks;

    if (_isLoadingBlocks && hasSelection && blocks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!hasSelection) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app,
                color: Colors.white24,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                '请在右侧"项"标签页选择一个项',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isLoadingBlocks && blocks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 48),
          child: Text(
            '暂无内容',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!hasSelection || !_hasMoreBlocks || _isLoadingBlocks) {
          return false;
        }
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          final selectedItem = context
              .read<AggregationProvider>()
              .items
              .where((item) => item.id == _selectedItemId)
              .firstOrNull;
          if (selectedItem != null) {
            _fetchBlocksByModel(
              context: context,
              model: selectedItem.model,
              page: _currentPage + 1,
              tag: _selectedTag,
            );
          }
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
                                child: CircularProgressIndicator(strokeWidth: 2),
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
  }
}

class _AggregationItemSimpleCard extends StatelessWidget {
  const _AggregationItemSimpleCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onOptions,
  });

  final AggregationItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${item.count}块',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      if (item.tags.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.label,
                                size: 10,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${item.tags.length}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onOptions,
              icon: const Icon(
                Icons.more_horiz,
                color: Colors.white54,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTagItem extends StatelessWidget {
  const _GroupTagItem({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.18)
              : Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? Colors.white70 : Colors.white10,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

enum _ItemAction { rename, changeModel, manageTags, delete }

class _ItemEditorDialog extends StatefulWidget {
  const _ItemEditorDialog({required this.onSubmit});

  final void Function(String title, String model) onSubmit;

  @override
  State<_ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<_ItemEditorDialog> {
  final _titleController = TextEditingController();
  final _modelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '新增项',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogTextField(
              controller: _titleController,
              label: '项名称',
              hintText: '例如：设计资源',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入项名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppDialogTextField(
              controller: _modelController,
              label: 'Model 类型',
              hintText: '请输入 Model ID',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入 Model 类型';
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
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(),
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
                  : () {
                      if (!_formKey.currentState!.validate()) {
                        return;
                      }
                      setState(() => _isSubmitting = true);
                      widget.onSubmit(
                        _titleController.text.trim(),
                        _modelController.text.trim(),
                      );
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

class _ModelSelectorDialog extends StatefulWidget {
  const _ModelSelectorDialog({required this.currentModel});

  final String currentModel;

  @override
  State<_ModelSelectorDialog> createState() => _ModelSelectorDialogState();
}

class _ModelSelectorDialogState extends State<_ModelSelectorDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentModel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '修改 Model 类型',
      content: Form(
        key: _formKey,
        child: AppDialogTextField(
          controller: _controller,
          label: 'Model 类型',
          hintText: '请输入 Model ID',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入 Model 类型';
            }
            return null;
          },
        ),
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
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(_controller.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }
}

