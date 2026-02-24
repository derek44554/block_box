import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../blocks/file/models/file_card_data.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../../../utils/cid_image_provider.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../models/photo_models.dart';


class ZoomableImage extends StatefulWidget {
  const ZoomableImage({super.key, required this.photo});

  final PhotoImage photo;

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  BlockImageResult? _placeholderImage;
  BlockImageResult? _originalImage;
  bool _hasError = false;
  late final FileCardData _fileData;

  @override
  void initState() {
    super.initState();
    _fileData = FileCardData.fromBlock(widget.photo.block);

    if (widget.photo.previewBytes != null) {
      _placeholderImage = _createResultFromBytes(
        widget.photo.previewBytes!,
        widget.photo.previewVariant ?? ImageVariant.medium,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImages());
  }

  Future<void> _loadImages() async {
    if (!mounted) return;

    final cid = _fileData.cid ?? '';
    if (cid.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    await _loadPlaceholder(cid);
    await _loadOriginal(cid);
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: _buildImageContent());
  }

  Widget _buildImageContent() {
    if (_hasError) {
      return const Icon(Icons.broken_image, color: Colors.white24, size: 48);
    }

    if (_placeholderImage == null && _originalImage == null) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_placeholderImage != null)
          Image(
            image: _placeholderImage!.provider,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          ),
        if (_originalImage != null)
          Image(
            image: _originalImage!.provider,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          ),
      ],
    );
  }

  Future<void> _loadPlaceholder(String cid) async {
    if (_placeholderImage != null) {
      return;
    }

    Uint8List? cachedBytes;
    ImageVariant? cachedVariant;
    final mediumBytes = ImageCacheHelper.getMemoryImage(
      cid,
      variant: ImageVariant.medium,
    );
    if (mediumBytes != null) {
      cachedBytes = mediumBytes;
      cachedVariant = ImageVariant.medium;
    } else {
      final smallBytes = ImageCacheHelper.getMemoryImage(
        cid,
        variant: ImageVariant.small,
      );
      if (smallBytes != null) {
        cachedBytes = smallBytes;
        cachedVariant = ImageVariant.small;
      }
    }

    if (cachedBytes != null && cachedVariant != null) {
      final resolvedBytes = cachedBytes;
      final resolvedVariant = cachedVariant;
      if (mounted) {
        setState(() {
          _placeholderImage = _createResultFromBytes(
            resolvedBytes,
            resolvedVariant,
          );
          _hasError = false;
        });
      }
      widget.photo.previewBytes = resolvedBytes;
      widget.photo.previewVariant = resolvedVariant;
      return;
    }

    final endpoint = context.read<ConnectionProvider>().ipfsEndpoint;
    if ((endpoint == null || endpoint.isEmpty) &&
        widget.photo.previewBytes == null) {
      if (mounted) {
        setState(() => _hasError = true);
      }
      return;
    }

    try {
      final result = await BlockImageLoader.instance.loadVariant(
        data: _fileData,
        endpoint: endpoint ?? '',
        variant: ImageVariant.medium,
        initialBytes: widget.photo.previewBytes,
        initialVariant: widget.photo.previewVariant,
      );
      if (!mounted) return;
      setState(() {
        _placeholderImage = result;
        _hasError = false;
      });
      widget.photo.previewBytes = result.bytes;
      widget.photo.previewVariant = result.variant;
    } catch (error) {
      debugPrint('[ZoomableImage] 加载预览失败: $error');
      if (mounted && _placeholderImage == null) {
        setState(() => _hasError = true);
      }
    }
  }

  Future<void> _loadOriginal(String cid) async {
    if (_originalImage != null) {
      return;
    }

    final endpoint = context.read<ConnectionProvider>().ipfsEndpoint;
    if (endpoint == null || endpoint.isEmpty) {
      if (mounted && _placeholderImage == null) {
        setState(() => _hasError = true);
      }
      return;
    }

    try {
      final result = await BlockImageLoader.instance.loadVariant(
        data: _fileData,
        endpoint: endpoint,
        variant: ImageVariant.original,
        initialBytes: _placeholderImage?.bytes,
        initialVariant: _placeholderImage?.variant,
      );
      if (!mounted) return;
      setState(() {
        _originalImage = result;
        _hasError = false;
      });
    } catch (error) {
      debugPrint('[ZoomableImage] 加载原图失败: $error');
      if (mounted && _originalImage == null) {
        setState(() => _hasError = true);
      }
    }
  }

  BlockImageResult _createResultFromBytes(
    Uint8List bytes,
    ImageVariant variant,
  ) {
    final cid = _fileData.cid ?? _fileData.bid ?? widget.photo.heroTag;
    ImageCacheHelper.cacheMemoryImage(cid, bytes, variant: variant);
    unawaited(ImageCacheHelper.saveImageToCache(cid, bytes, variant: variant));
    unawaited(ImageCacheHelper.warmUpMemoryCache(cid, bytes, variant: variant));
    final provider = CidImageProvider(
      cid: ImageCacheHelper.composeKey(cid, variant),
      bytesResolver: () async => bytes,
    );
    return BlockImageResult(
      bytes: bytes,
      variant: variant,
      provider: provider,
      source: ImageLoadSource.external,
    );
  }
}
