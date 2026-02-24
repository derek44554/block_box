import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/models/block_model.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../widgets/border/block_border.dart';
import '../models/file_card_data.dart';

class ImageFileCard extends StatefulWidget {
  const ImageFileCard({
    super.key,
    required this.block,
    required this.cardData,
    this.onTap,
  });

  final BlockModel block;
  final FileCardData cardData;
  final VoidCallback? onTap;

  @override
  State<ImageFileCard> createState() => _ImageFileCardState();
}

class _ImageFileCardState extends State<ImageFileCard> {
  BlockImageResult? _imageResult;
  bool _isLoading = true;
  bool _hasError = false;
  bool _loadTriggered = false;

  Future<void> _loadImage() async {
    if (_loadTriggered || !mounted) {
      return;
    }
    _loadTriggered = true;

    setState(() {
      if (_imageResult == null) {
        _isLoading = true;
      }
      _hasError = false;
    });

    try {
      final endpoint = context.read<ConnectionProvider>().ipfsEndpoint ?? '';
      final result = await BlockImageLoader.instance.loadVariant(
        data: widget.cardData,
        endpoint: endpoint,
        variant: ImageVariant.medium,
      );
      if (!mounted) return;
      setState(() {
        _imageResult = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          widget.onTap ??
          () {
            AppRouter.openBlockDetailPage(
              context,
              widget.block,
              initialImageBytes: _imageResult?.bytes,
              initialImageVariant: _imageResult?.variant,
            );
          },
      child: VisibilityDetector(
        key: Key('image_file_card_${widget.cardData.bid}'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0) {
            _loadImage();
          }
        },
        child: BlockBorder(
          child: Container(
            decoration: const BoxDecoration(color: Colors.black),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: _buildImageContent()),
                  if (widget.cardData.encryption?.isSupported == true)
                    const Positioned(
                      bottom: 8,
                      right: 8,
                      child: Icon(
                        Icons.lock_outline,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_hasError) {
      return const Icon(Icons.error_outline, color: Colors.white24, size: 48);
    }
    if (_isLoading && _imageResult == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
      );
    }
    if (_imageResult != null) {
      return Image(
        image: _imageResult!.provider,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return Container(color: Colors.grey.shade900);
  }
}
