import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../blocks/file/models/file_card_data.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../models/photo_models.dart';

typedef PhotoGridTapCallback = void Function(int index);

class PhotoBlockGrid extends StatelessWidget {
  const PhotoBlockGrid({
    super.key,
    required this.photos,
    required this.onTap,
    this.crossAxisCount = 4,
    this.spacing = 6.0,
    this.horizontalPadding = 14.0,
    this.onLoadMore,
    this.canLoadMore = false,
    this.isLoadingMore = false,
  });

  final List<PhotoImage> photos;
  final PhotoGridTapCallback onTap;
  final int crossAxisCount;
  final double spacing;
  final double horizontalPadding;
  final VoidCallback? onLoadMore;
  final bool canLoadMore;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (crossAxisCount - 1);
        final availableWidth =
            constraints.maxWidth - (horizontalPadding * 2) - totalSpacing;
        final itemSize = availableWidth / crossAxisCount;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (onLoadMore == null || !canLoadMore || isLoadingMore) {
              return false;
            }
            if (notification is ScrollUpdateNotification ||
                notification is OverscrollNotification) {
              final metrics = notification.metrics;
              if (metrics.maxScrollExtent > 0 &&
                  metrics.pixels >= metrics.maxScrollExtent - itemSize * 1.5) {
                onLoadMore!.call();
              }
            }
            return false;
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  24,
                ),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= photos.length) {
                      return const SizedBox.shrink();
                    }
                    final item = photos[index];
                    return SizedBox(
                      width: itemSize,
                      height: itemSize,
                      child: RepaintBoundary(
                        child: _PhotoGridItem(
                          key: ValueKey(item.heroTag),
                          photo: item,
                          onTap: () => onTap(index),
                          targetSize: itemSize,
                        ),
                      ),
                    );
                  }, childCount: photos.length),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: 1,
                  ),
                ),
              ),
              if (isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 28),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoGridItem extends StatefulWidget {
  const _PhotoGridItem({
    super.key,
    required this.photo,
    required this.onTap,
    required this.targetSize,
  });

  final PhotoImage photo;
  final VoidCallback onTap;
  final double targetSize;

  @override
  State<_PhotoGridItem> createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<_PhotoGridItem> {
  BlockImageResult? _imageResult;
  bool _isLoading = true;
  bool _hasError = false;
  late final FileCardData _fileData;

  @override
  void initState() {
    super.initState();
    _fileData = FileCardData.fromBlock(widget.photo.block);
    _loadImage();
  }

  Future<void> _loadImage() async {
    final cid = widget.photo.cid;
    if (cid.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    try {
      final connection = Provider.of<ConnectionProvider>(context, listen: false);
      final endpoint = connection.ipfsEndpoint;

      final result = await BlockImageLoader.instance.loadVariant(
        data: _fileData,
        variant: ImageVariant.small,
        endpoint: endpoint ?? '',
        initialBytes: widget.photo.previewBytes,
        initialVariant: widget.photo.previewVariant,
      );

      if (!mounted) return;

      widget.photo.previewBytes = result.bytes;
      widget.photo.previewVariant = result.variant;

      setState(() {
        _imageResult = result;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSupported = widget.photo.isSupportedImage;
    final showImage = !isSupported
        ? false
        : (_imageResult != null);

    ImageProvider? imageProvider;
    if (showImage) {
      final cacheWidth = (widget.targetSize * 2).toInt().clamp(100, 600);
      imageProvider = ResizeImage(
        _imageResult!.provider,
        width: cacheWidth,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Hero(
        tag: widget.photo.heroTag,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF222225),
            borderRadius: BorderRadius.circular(6),
            image: imageProvider != null
                ? DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _buildContent(isSupported),
        ),
      ),
    );
  }

  Widget? _buildContent(bool isSupported) {
    // 如果图片已显示，不需要子内容
    if (isSupported && !_isLoading && !_hasError && _imageResult != null) {
      return null;
    }

    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white24,
          ),
        ),
      );
    }

    // 错误或不支持的格式
    if (_hasError || !isSupported) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSupported ? Icons.broken_image_outlined : Icons.videocam_outlined,
            color: Colors.white24,
            size: 32,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              widget.photo.title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return null;
  }
}
