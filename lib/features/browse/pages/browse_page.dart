import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../blocks/common/block_type_ids.dart';
import '../../../components/block/block_card_factory.dart';
import '../../../core/models/block_model.dart';
import '../../../core/network/api/block_api.dart';
import '../../../core/widgets/layouts/segmented_page_scaffold.dart';
import '../../../state/connection_provider.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  static const int _pageLimit = 20;
  static const Map<String, String> _modelOptions = {
    BlockTypeIds.generic: '普通块',
    BlockTypeIds.document: '文档',
    BlockTypeIds.article: '文章',
    BlockTypeIds.service: '服务',
    BlockTypeIds.set: '集合',
    BlockTypeIds.file: '文件',
    BlockTypeIds.user: '用户',
    BlockTypeIds.record: '档案',
    BlockTypeIds.gps: 'GPS',
    BlockTypeIds.creed: '信条',
  };

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<BlockModel> _blocks = const [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _activeRequestKey;
  String? _selectedModel;
  String _selectedOrder = 'desc';
  String? _appliedModel;
  String? _appliedTag;
  String _appliedOrder = 'desc';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBlocks(page: 1);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _modelController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoading || !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _fetchBlocks(page: _currentPage + 1);
    }
  }

  Future<void> _fetchBlocks({required int page}) async {
    if (_isLoading) {
      return;
    }

    final requestKey =
        'browse#$page#${_appliedModel ?? ""}#${_appliedTag ?? ""}#$_appliedOrder';
    _activeRequestKey = requestKey;
    setState(() {
      _isLoading = true;
      if (page == 1) {
        _errorMessage = null;
      }
    });

    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final response = await api.getAllBlocks(
        page: page,
        limit: _pageLimit,
        order: _appliedOrder,
        model: _emptyToNull(_appliedModel),
        tag: _emptyToNull(_appliedTag),
      );

      if (!mounted || _activeRequestKey != requestKey) {
        return;
      }

      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw Exception('浏览请求返回数据格式无效');
      }

      final items = data['items'];
      if (items is! List) {
        throw Exception('浏览请求 items 数据格式无效');
      }

      final fetchedBlocks = items
          .whereType<Map<String, dynamic>>()
          .map((item) => BlockModel(data: item))
          .toList();

      setState(() {
        if (page == 1) {
          _blocks = fetchedBlocks;
        } else {
          final existing = _blocks
              .map((block) => block.data['bid'])
              .whereType<String>()
              .toSet();
          final merged = List<BlockModel>.from(_blocks);
          for (final block in fetchedBlocks) {
            final bid = block.data['bid'];
            if (bid is String && existing.contains(bid)) {
              continue;
            }
            merged.add(block);
            if (bid is String) {
              existing.add(bid);
            }
          }
          _blocks = merged;
        }
        _currentPage = data['page'] is int ? data['page'] as int : page;

        final count = data['count'];
        if (count is int) {
          _hasMore = _blocks.length < count;
        } else {
          _hasMore = fetchedBlocks.length >= _pageLimit;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    } finally {
      if (_activeRequestKey == requestKey) {
        _activeRequestKey = null;
      }
      if (mounted) {
        setState(() => _isLoading = false);
        _queueAutoLoadMoreIfNeeded();
      }
    }
  }

  void _queueAutoLoadMoreIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoading || !_hasMore || !_scrollController.hasClients) {
        return;
      }
      if (_scrollController.position.maxScrollExtent <= 0) {
        _fetchBlocks(page: _currentPage + 1);
      }
    });
  }

  void _applyFilters() {
    final model = _emptyToNull(_modelController.text.trim());
    final tag = _emptyToNull(_tagController.text.trim());
    _applyFilterValues(model: model, tag: tag, order: _selectedOrder);
  }

  void _applyFilterValues({
    required String? model,
    required String? tag,
    required String order,
  }) {
    _modelController.text = model ?? '';
    _tagController.text = tag ?? '';
    setState(() {
      _selectedModel = model;
      _selectedOrder = order;
      _appliedModel = model;
      _appliedTag = tag;
      _appliedOrder = order;
      _blocks = const [];
      _currentPage = 1;
      _hasMore = true;
      _errorMessage = null;
    });
    _fetchBlocks(page: 1);
  }

  void _selectModel(String? model) {
    setState(() {
      _selectedModel = model;
      _modelController.text = model ?? '';
    });
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return SegmentedPageScaffold(
      title: '浏览',
      segments: const ['内容', '筛选'],
      pages: [
        _buildContentPage(),
        _buildFilterPage(),
      ],
    );
  }

  Widget _buildContentPage() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (_isLoading && _blocks.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage != null && _blocks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _BrowseMessage(
              icon: Icons.error_outline,
              title: '加载失败',
              message: _errorMessage!,
              actionLabel: '重试',
              onAction: () => _fetchBlocks(page: 1),
            ),
          )
        else if (_blocks.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _BrowseMessage(
              icon: Icons.inventory_2_outlined,
              title: '暂无内容',
              message: '当前条件下没有可显示的 Block',
            ),
          )
        else
          _buildBlockList(),
        SliverToBoxAdapter(child: _buildTailIndicator()),
      ],
    );
  }

  Widget _buildFilterPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 820;
        final horizontalPadding = isWide ? 28.0 : 20.0;
        final contentWidth = isWide ? 720.0 : double.infinity;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '筛选条件',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildFilters(isWide),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BrowseTextField(
          controller: _modelController,
          label: '类型',
          hintText: '输入 model 或选择类型',
          onSubmitted: (_) => _applyFilters(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ModelChip(
              label: '全部类型',
              selected: _selectedModel == null,
              onTap: () => _selectModel(null),
            ),
            for (final entry in _modelOptions.entries)
              _ModelChip(
                label: entry.value,
                selected: _selectedModel == entry.key,
                onTap: () => _selectModel(entry.key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: isWide ? 220 : double.infinity,
              child: _BrowseTextField(
                controller: _tagController,
                label: '标签',
                hintText: '输入标签',
                onSubmitted: (_) => _applyFilters(),
              ),
            ),
            SizedBox(
              width: isWide ? 190 : double.infinity,
              child: _OrderSelector(
                value: _selectedOrder,
                onChanged: (value) => setState(() => _selectedOrder = value),
              ),
            ),
            SizedBox(
              width: isWide ? 96 : double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _applyFilters,
                icon: const Icon(Icons.search, size: 17),
                label: const Text('应用'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white38,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlockList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.crossAxisExtent >= 820;
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final block = _blocks[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 820 : double.infinity,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _blocks.length - 1 ? 0 : 16,
                      ),
                      child: BlockCardFactory.build(block),
                    ),
                  ),
                );
              },
              childCount: _blocks.length,
              addAutomaticKeepAlives: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTailIndicator() {
    if (_blocks.isEmpty) {
      return const SizedBox(height: 32);
    }

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white30,
            ),
          ),
        ),
      );
    }

    if (_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '上拉加载更多',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }

    return const SizedBox(height: 32);
  }
}

class _BrowseTextField extends StatelessWidget {
  const _BrowseTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: 1,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.34)),
        ),
      ),
    );
  }
}

class _OrderSelector extends StatelessWidget {
  const _OrderSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1E1E1E),
      iconEnabledColor: Colors.white54,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: '排序方式',
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.34)),
        ),
      ),
      items: const [
        DropdownMenuItem<String>(
          value: 'desc',
          child: Text('最新'),
        ),
        DropdownMenuItem<String>(
          value: 'asc',
          child: Text('最早'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.white54 : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _BrowseMessage extends StatelessWidget {
  const _BrowseMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 46),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.18)),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
