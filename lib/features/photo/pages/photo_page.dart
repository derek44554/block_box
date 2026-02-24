// 照片页展示 BID 关联的照片与集合，支持本地集合管理和图片预览。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';
import 'package:block_app/core/network/api/block_api.dart';
import 'package:block_app/core/widgets/dialogs/confirmation_dialog.dart';

import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../state/connection_provider.dart';
import '../models/photo_models.dart';
import '../providers/photo_provider.dart';
import '../widgets/photo_segmented_page.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/photo_block_grid.dart';
import '../widgets/collection_list.dart';
import 'package:block_app/core/utils/helpers/platform_helper.dart';

class PhotoPage extends StatefulWidget {
  const PhotoPage({super.key});

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  int? _selectedCollectionIndex;
  List<BlockModel> _photoBlocks = [];
  List<PhotoImage> _photoImages = [];
  bool _isLoadingPhotos = false;
  bool _isLoadingMorePhotos = false;
  String? _photoError;
  bool _isAddingCollection = false;
  String? _addingError;
  _PhotoGridKey? _lastLoadedKey;
  int _currentPage = 1;
  bool _hasMorePhotos = true;
  static const int _pageSize = 40;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PhotoSegmentedPage(
      photos: _buildAlbumPhotoGrid(context),
      collections: _buildCollectionPane(context),
      onPageChanged: (index) {
        // 页面切换时不清除选中状态，保持用户选择
      },
    );
  }

  void _handleCollectionToggle(int index) {
    setState(() {
      if (_selectedCollectionIndex == index) {
        _selectedCollectionIndex = null;
      } else {
        _selectedCollectionIndex = index;
      }
      _lastLoadedKey = null; // 重置标记，触发重新加载
      _currentPage = 1;
      _hasMorePhotos = true;
      _photoBlocks = [];
      _photoImages = [];
    });
  }

  Widget _buildAlbumPhotoGrid(BuildContext context) {
    return Selector<PhotoProvider, _PhotoGridKey>(
      selector: (_, provider) => _PhotoGridKey(
        albumBids: provider.albumCollections.map((c) => c.bid).toList(),
        selectedBid:
            _selectedCollectionIndex != null &&
                _selectedCollectionIndex! < provider.collections.length
            ? provider.collections[_selectedCollectionIndex!].bid
            : null,
      ),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, gridKey, _) {
        // 只有当 key 变化时才重新加载照片
        if (_lastLoadedKey != gridKey && !_isLoadingPhotos) {
          _lastLoadedKey = gridKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadPhotos();
          });
        }
        
        if (_isLoadingPhotos && _photoImages.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          );
        }
        
        if (_photoError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white24,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _photoError!,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    _lastLoadedKey = null; // 重置标记以允许重新加载
                    _loadPhotos();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        
        if (_photoBlocks.isEmpty && !_isLoadingPhotos) {
          return const Center(
            child: Text(
              '暂无照片',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          );
        }
        
        return LayoutBuilder(
          builder: (context, constraints) {
            // 根据屏幕宽度自动计算每行显示的照片数量
            // 每个照片的最小宽度设为 100，间距为 6，平衡显示数量和视觉效果
            const double minItemWidth = 100.0;
            const double spacing = 6.0;
            const double horizontalPadding = 14.0;
            
            final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
            int crossAxisCount = ((availableWidth + spacing) / (minItemWidth + spacing)).floor();
            
            // 确保至少显示 2 列，最多显示 8 列
            crossAxisCount = crossAxisCount.clamp(2, 8);
            
            return PhotoBlockGrid(
              photos: _photoImages,
              crossAxisCount: crossAxisCount,
              spacing: spacing,
              onTap: _openBlockViewer,
              onLoadMore: () => _loadPhotos(loadMore: true),
              canLoadMore: _hasMorePhotos,
              isLoadingMore: _isLoadingMorePhotos,
            );
          },
        );
      },
    );
  }

  Widget _buildCollectionPane(BuildContext context) {
    return Selector<PhotoProvider, List<PhotoCollection>>(
      selector: (_, provider) => provider.collections,
      builder: (context, collections, _) {
        return CollectionList(
          collections: collections,
          selectedIndex: _selectedCollectionIndex,
          onToggle: _handleCollectionToggle,
          onAdd: _showAddCollectionDialog,
          onDelete: _confirmDeleteCollection,
          onAlbumToggle: (bid, isAlbum) =>
              context.read<PhotoProvider>().toggleAlbum(bid, isAlbum),
          isLoading: _isAddingCollection,
          errorMessage: _addingError,
        );
      },
    );
  }

  void _showAddCollectionDialog() {
    if (_isAddingCollection) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _PhotoCollectionDialog(onSubmit: _handleAddCollection),
    );
  }

  Future<void> _handleAddCollection(String bid) async {
    final normalizedBid = bid.trim();
    if (normalizedBid.isEmpty) {
      throw ArgumentError('请输入有效的 BID');
    }

    setState(() {
      _isAddingCollection = true;
      _addingError = null;
    });

    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final response = await api.getBlock(bid: normalizedBid);
      final data = response['data'];

      if (data is! Map<String, dynamic> || data.isEmpty) {
        throw StateError('未获取到有效的块数据');
      }

      final block = Map<String, dynamic>.from(data);
      final resolvedBid = (block['bid'] as String?)?.trim();
      if (resolvedBid == null || resolvedBid.isEmpty) {
        block['bid'] = normalizedBid;
      }

      final collection = PhotoCollection(
        bid: block['bid'] as String,
        block: block,
      );

      await _addCollection(collection);

      if (!mounted) {
        return;
      }

      setState(() {
        _addingError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加 ${collection.title ?? collection.bid}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ArgumentError catch (error) {
      _setAddCollectionError(error.message ?? '参数错误');
      rethrow;
    } on StateError catch (error) {
      _setAddCollectionError(error.message);
      rethrow;
    } catch (error, stack) {
      debugPrint(
        'Failed to add photo collection for bid=$normalizedBid: $error',
      );
      debugPrint('$stack');
      const message = '加载失败，请稍后重试';
      _setAddCollectionError(message);
      throw StateError(message);
    } finally {
      if (mounted) {
      setState(() {
          _isAddingCollection = false;
        });
      } else {
        _isAddingCollection = false;
      }
    }
  }

  void _setAddCollectionError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _addingError = message;
    });
  }

  Future<void> _loadPhotos({bool loadMore = false}) async {
    if (!loadMore && _isLoadingPhotos) {
      return;
    }
    if (loadMore && (_isLoadingPhotos || _isLoadingMorePhotos)) {
      return;
    }
    if (loadMore && !_hasMorePhotos) {
      return;
    }

    final photoProvider = context.read<PhotoProvider>();
    
    // 确定要查询的 BID 列表
    List<String> bidsToQuery;
    if (_selectedCollectionIndex != null &&
        _selectedCollectionIndex! < photoProvider.collections.length) {
      // 选中了单个集合，使用该集合的 BID
      bidsToQuery = [photoProvider.collections[_selectedCollectionIndex!].bid];
    } else {
      // 未选中或索引无效，使用所有已加入相册的 BID
      bidsToQuery = photoProvider.albumCollections.map((c) => c.bid).toList();
    }

    if (bidsToQuery.isEmpty) {
      setState(() {
        _photoBlocks = [];
        _photoImages = [];
        _photoError = null;
        _isLoadingPhotos = false;
        _isLoadingMorePhotos = false;
        _currentPage = 1;
        _hasMorePhotos = false;
      });
      return;
    }

    final targetPage = loadMore ? _currentPage + 1 : 1;

    setState(() {
      if (loadMore) {
        _isLoadingMorePhotos = true;
      } else {
      _isLoadingPhotos = true;
      _photoError = null;
        _currentPage = 1;
        _hasMorePhotos = true;
      }
    });

    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final Map<String, dynamic> response = await api.getLinksByTargets(
        bids: bidsToQuery,
        page: targetPage,
        limit: _pageSize,
        order: 'desc',
      );

      if (!mounted) return;

      // 参考 link_page.dart 的数据提取方式
      final data = response['data'];

      final blocks = _extractBlocksFromResponse(data);

      final images = blocks.map(_buildPhotoImage).toList(growable: false);
      
      setState(() {
        if (loadMore) {
          _currentPage = targetPage;
          _photoBlocks = [..._photoBlocks, ...blocks];
          _photoImages = [..._photoImages, ...images];
        } else {
          _currentPage = targetPage;
          _photoBlocks = blocks;
          _photoImages = images;
        }
        _hasMorePhotos = blocks.length >= _pageSize;
        _isLoadingPhotos = false;
        _isLoadingMorePhotos = false;
      });
      
      // 如果是第一页加载且内容不足，自动加载更多
      if (!loadMore && _hasMorePhotos && images.length < 20) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _hasMorePhotos && !_isLoadingMorePhotos) {
            _loadPhotos(loadMore: true);
          }
        });
      }
    } catch (error, stackTrace) {
      debugPrint('[PhotoPage] 加载照片失败: $error');
      debugPrint('[PhotoPage] 堆栈跟踪: $stackTrace');
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _isLoadingMorePhotos = false;
          _hasMorePhotos = false;
        } else {
        _photoError = '加载失败，请稍后重试';
        _isLoadingPhotos = false;
        }
      });
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

    final allBlocks = items
        .whereType<Map<String, dynamic>>()
        .map((item) => BlockModel(data: item))
          .toList();

    // 文件块 model ID
    const fileModelId = 'c4238dd0d3d95db7b473adb449f6d282';

    // 支持的图片扩展名
    const imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.JPG',
      '.JPEG',
      '.PNG',
      '.GIF',
      '.WEBP',
      '.BMP',
    ];

    
    // 过滤出文件块：model 为文件块 且有有效的 ipfs 字段
    final fileBlocks = allBlocks.where((block) {
          // 检查是否为文件块
          final model = block.maybeString('model');
          final isFileBlock = model == fileModelId;

          if (!isFileBlock) {
            return false;
          }

          // 检查 ipfs 字段
          final ipfs = block.map('ipfs');
          final hasValidIpfs = !ipfs.isEmpty && ipfs['cid'] != null;

          if (!hasValidIpfs) {
            return false;
          }

          // 现在接受所有文件格式，包括视频等
          return true;
    }).toList();
    
    return fileBlocks;
  }

  PhotoImage _buildPhotoImage(BlockModel block) {
    final title =
        block.maybeString('name') ??
        block.maybeString('fileName') ??
        '图片';
    final cid = block.map('ipfs')['cid'] as String? ?? '';
    final bid = block.maybeString('bid') ?? cid;
    final heroTag = cid.isNotEmpty ? 'cid://$cid' : 'bid://$bid';
    final createdAt =
        block.getDateTime('add_time') ?? block.getDateTime('createdAt');
    final time = createdAt != null
        ? formatDate(createdAt)
        : (block.maybeString('add_time') ?? '');

    // 检查是否为支持的图片格式
    final ipfs = block.map('ipfs');
    final ext = ipfs['ext'] as String?;
    final imageExtensions = [
      '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp',
      '.JPG', '.JPEG', '.PNG', '.GIF', '.WEBP', '.BMP'
    ];
    final isSupportedImage = ext != null && imageExtensions.contains(ext);

    final photoImage = PhotoImage(
      block: block,
      heroTag: heroTag,
      title: title,
      time: time,
      isSupportedImage: isSupportedImage,
    );

    return photoImage;
  }

  void _openBlockViewer(int index) {
    if (_photoImages.isEmpty || index < 0 || index >= _photoImages.length) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PhotoViewerPage(photos: _photoImages, initialIndex: index),
      ),
    );
  }

  Future<void> _addCollection(PhotoCollection collection) async {
    await context.read<PhotoProvider>().addCollection(collection);
  }

  Future<void> _confirmDeleteCollection(PhotoCollection collection) async {
    final confirm = await showConfirmationDialog(
      context: context,
      title: '确认删除该集合？',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '集合：${collection.title ?? collection.bid}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text(
            '删除后不可恢复，是否继续？',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      confirmText: '删除',
      isDestructive: true,
    );

    if (confirm != true) {
      return;
    }

    await context.read<PhotoProvider>().removeCollection(collection.bid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 ${collection.title ?? collection.bid}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _PhotoCollectionDialog extends StatefulWidget {
  const _PhotoCollectionDialog({required this.onSubmit});

  final Future<void> Function(String bid) onSubmit;

  @override
  State<_PhotoCollectionDialog> createState() => _PhotoCollectionDialogState();
}

class _PhotoCollectionDialogState extends State<_PhotoCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bidController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '新增集合',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogTextField(
              controller: _bidController,
              label: '集合 BID',
              hintText: '32 位块 ID',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入集合 BID';
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
                      await widget.onSubmit(_bidController.text.trim());
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

class _PhotoGridKey {
  const _PhotoGridKey({required this.albumBids, required this.selectedBid});

  final List<String> albumBids;
  final String? selectedBid;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _PhotoGridKey) return false;
    return selectedBid == other.selectedBid &&
        albumBids.length == other.albumBids.length &&
        _listEquals(albumBids, other.albumBids);
  }

  @override
  int get hashCode => Object.hash(selectedBid, Object.hashAll(albumBids));

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
