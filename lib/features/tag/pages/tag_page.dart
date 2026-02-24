import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:block_app/core/network/api/block_api.dart';

import '../../../components/block/block_card_factory.dart';
import '../../../core/models/block_model.dart';
import '../../../state/connection_provider.dart';
import '../widgets/tag_header.dart';

class TagPage extends StatefulWidget {
  const TagPage({super.key, required this.tag});

  final String tag;

  @override
  State<TagPage> createState() => _TagPageState();
}

class _TagPageState extends State<TagPage> {
  static const int _pageSize = 20;

  final List<BlockModel> _blocks = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBlocks());
  }

  Future<void> _fetchBlocks({bool loadMore = false}) async {
    if (_isLoading || _isLoadingMore) {
      return;
    }

    final targetPage = loadMore ? _currentPage + 1 : 1;

    if (loadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        if (!loadMore) {
          _hasMore = true;
        }
      });
    }

    try {
      final api = BlockApi(connectionProvider: context.read<ConnectionProvider>());
      final response = await api.getBlocksByTag(
        name: widget.tag,
        page: targetPage,
        limit: _pageSize,
      );
      final data = response['data'];
      final fetchedBlocks = _extractBlocks(data);

      if (!mounted) return;
      setState(() {
        if (targetPage == 1) {
          _blocks
            ..clear()
            ..addAll(fetchedBlocks);
        } else {
          for (final block in fetchedBlocks) {
            final bid = block.maybeString('bid');
            final alreadyExists = _blocks.any((item) => item.maybeString('bid') == bid);
            if (!alreadyExists) {
              _blocks.add(block);
            }
          }
        }
        _currentPage = targetPage;
        _hasMore = fetchedBlocks.length >= _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _isLoadingMore = false;
        } else {
          _isLoading = false;
        }
        _error = error.toString();
      });
    }
  }

  List<BlockModel> _extractBlocks(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final items = payload['items'];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map((item) => BlockModel(data: item))
            .toList();
      }
    }
    return const <BlockModel>[];
  }

  Future<void> _handleRefresh() async {
    await _fetchBlocks(loadMore: false);
  }

  void _handleRetry() {
    _fetchBlocks(loadMore: false);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!_hasMore || _isLoading || _isLoadingMore) {
      return false;
    }

    if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
      _fetchBlocks(loadMore: true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(toolbarHeight: 0),
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          color: Colors.white,
          backgroundColor: Colors.grey.shade900,
          onRefresh: _handleRefresh,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _blocks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
            ),
          ),
        ],
      );
    }

    if (_error != null && _blocks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _handleRetry,
                  child: const Text('重新加载'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_blocks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        children: const [
          Center(
            child: Text(
              '暂无相关块内容',
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  TagHeader(tag: widget.tag),
                  for (var i = 0; i < _blocks.length; i++) ...[
                    BlockCardFactory.build(_blocks[i]),
                    if (i != _blocks.length - 1) const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
                  ),
                ),
              ),
            )
          else if (_hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Center(
                  child: Text(
                    '上拉加载更多',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
