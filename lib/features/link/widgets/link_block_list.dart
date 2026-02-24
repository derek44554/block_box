import 'package:flutter/material.dart';

import '../../../components/block/block_card_factory.dart';
import '../../../components/block/block_grid_layout.dart';
import '../../../core/models/block_model.dart';
import 'link_empty_view.dart';
import 'link_error_view.dart';
import 'link_loading_view.dart';

class LinkBlockList extends StatefulWidget {
  const LinkBlockList({
    super.key,
    required this.blocks,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.onLoadMore,
    this.useGridLayout = false,
    this.onBlockLongPress,
  });

  final List<BlockModel> blocks;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final bool useGridLayout;
  final void Function(BlockModel block)? onBlockLongPress;

  @override
  State<LinkBlockList> createState() => _LinkBlockListState();
}

class _LinkBlockListState extends State<LinkBlockList> {
  bool _hasCheckedAutoLoad = false;

  @override
  void didUpdateWidget(LinkBlockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当数据更新时重置自动加载检查
    if (oldWidget.blocks.length != widget.blocks.length) {
      _hasCheckedAutoLoad = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.blocks.isEmpty) {
      return const LinkLoadingView();
    }

    if (widget.error != null) {
      if (widget.blocks.isEmpty) {
        return LinkErrorView(message: widget.error!, onRetry: widget.onRetry);
      }
    }

    if (widget.blocks.isEmpty) {
      return const LinkEmptyView();
    }

    final shouldListen = widget.onLoadMore != null && widget.hasMore;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slivers = <Widget>[
          SliverPadding(
            padding: widget.useGridLayout
                ? const EdgeInsets.fromLTRB(24, 12, 24, 0)
                : const EdgeInsets.fromLTRB(24, 0, 24, 0),
            sliver: widget.useGridLayout ? _buildGridSliver() : _buildListSliver(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            sliver: SliverToBoxAdapter(
              child: _buildTailIndicator(),
            ),
          ),
        ];

        final scrollView = CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          cacheExtent: widget.useGridLayout ? 200 : null,
          slivers: slivers,
        );

        if (!shouldListen) {
          return scrollView;
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // 检查是否需要自动加载更多（当内容不足填满屏幕时）
            if (notification is ScrollUpdateNotification) {
              _checkAutoLoadMore(notification, constraints);
            }
            
            // 原有的上拉加载逻辑
            if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
              if (!widget.isLoadingMore) {
                widget.onLoadMore?.call();
              }
            }
            return false;
          },
          child: scrollView,
        );
      },
    );
  }

  void _checkAutoLoadMore(ScrollUpdateNotification notification, BoxConstraints constraints) {
    // 如果已经检查过或正在加载，跳过
    if (_hasCheckedAutoLoad || widget.isLoadingMore || !widget.hasMore) {
      return;
    }

    // 如果内容不足以填满屏幕，自动加载更多
    if (notification.metrics.maxScrollExtent <= 0) {
      _hasCheckedAutoLoad = true;
      // 延迟执行以避免在构建过程中调用setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.hasMore && !widget.isLoadingMore && widget.onLoadMore != null) {
          widget.onLoadMore!();
        }
      });
    }
  }

  Widget _buildTailIndicator() {
    if (widget.isLoadingMore) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white30,
          ),
        ),
      );
    }
    if (widget.hasMore) {
      return const Center(
        child: Text(
          '上拉加载更多',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildListSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final block = widget.blocks[index];
          final card = BlockCardFactory.build(block);
          
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == widget.blocks.length - 1 ? 0 : 16,
            ),
            child: widget.onBlockLongPress != null
                ? GestureDetector(
                    onLongPress: () => widget.onBlockLongPress?.call(block),
                    child: card,
                  )
                : card,
          );
        },
        childCount: widget.blocks.length,
      ),
    );
  }

  Widget _buildGridSliver() {
    return SliverBlockGrid(
      blocks: widget.blocks,
      onBlockLongPress: widget.onBlockLongPress,
    );
  }
}

