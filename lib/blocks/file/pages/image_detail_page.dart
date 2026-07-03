import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/block_model.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/utils/formatters/file_size_formatter.dart';
import '../../common/block_detail_page.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../../../utils/cid_image_provider.dart';
import '../models/file_card_data.dart';
import '../../../state/block_detail_listener_mixin.dart';

class ImageDetailPage extends StatefulWidget {
  final BlockModel block;
  final Uint8List? initialBytes;
  final ImageVariant? initialVariant;

  const ImageDetailPage({super.key, required this.block})
    : initialBytes = null,
      initialVariant = null;

  const ImageDetailPage.fromBytes({
    super.key,
    required this.block,
    required Uint8List bytes,
    ImageVariant variant = ImageVariant.medium,
  }) : initialBytes = bytes,
       initialVariant = variant;

  @override
  State<ImageDetailPage> createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends State<ImageDetailPage>
    with BlockDetailListenerMixin {
  late FileCardData _data;
  BlockImageResult? _imageResult;
  bool _isLoading = false;
  String? _error;
  bool _loadingOriginal = false;
  bool _isDownloading = false;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _data = FileCardData.fromBlock(updatedBlock);
      // Reset image loading state if file changed
      _imageResult = null;
      _isLoading = false;
      _error = null;
      _loadingOriginal = false;
    });
    // Reload image with new data
    _loadImage();
  }

  @override
  void initState() {
    super.initState();
    _data = FileCardData.fromBlock(widget.block);
    startBlockProviderListener();
    if (widget.initialBytes != null) {
      _imageResult = _createInitialResult(
        widget.initialBytes!,
        widget.initialVariant ?? ImageVariant.medium,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage());
  }

  @override
  void dispose() {
    stopBlockProviderListener();
    super.dispose();
  }

  void _safeSetState(VoidCallback action) {
    if (!mounted) return;
    setState(action);
  }

  Future<void> _loadImage() async {
    if (_loadingOriginal || _imageResult?.variant == ImageVariant.original) {
      return;
    }
    _loadingOriginal = true;

    _safeSetState(() {
      if (_imageResult == null) {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      final endpoint = context.read<ConnectionProvider>().ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        throw Exception('IPFS endpoint is not set');
      }
      final result = await BlockImageLoader.instance.loadVariant(
        data: _data,
        endpoint: endpoint,
        variant: ImageVariant.original,
        initialBytes: widget.initialBytes,
        initialVariant: widget.initialVariant,
      );
      _safeSetState(() {
        _imageResult = result;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      _safeSetState(() {
        if (_imageResult == null) {
          _isLoading = false;
        }
        _error = '加载失败：$error';
      });
    } finally {
      _loadingOriginal = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _data.fileName;
    final intro = _data.intro;
    final bid = _data.bid;
    final createdAt = _data.createdAt;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      body: Container(
        color: Colors.black,
        child: RefreshIndicator(
          onRefresh: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlockDetailPage(block: widget.block),
              ),
            );
          },
          color: Colors.white,
          backgroundColor: Colors.grey.shade900,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    const SizedBox(height: 48),
                    _buildImageSection(),
                    _buildFileInfo(createdAt),
                    if (_data.gps != null) _buildGpsInfo(_data.gps!),
                    if (fileName.isNotEmpty) _buildTitle(fileName),
                    if (intro != null && intro.isNotEmpty) _buildIntro(intro),
                    _buildDownloadSection(),
                    if (bid.isNotEmpty) _buildBid(bid),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '图片文件',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: GestureDetector(
            onTap: _openFullScreenViewer,
            child: _buildImageContent(),
          ),
        ),
      ),
    );
  }

  void _openFullScreenViewer() {
    if (_imageResult == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePage(imageResult: _imageResult!),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_isLoading) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.white24,
            size: 64,
          ),
        ),
      );
    }

    if (_imageResult != null) {
      return Image(image: _imageResult!.provider, fit: BoxFit.cover);
    }

    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white24, size: 64),
      ),
    );
  }

  Widget _buildFileInfo(DateTime createdAt) {
    final fileSize = _data.ipfsSize;
    final isEncrypted = _data.encryption?.isSupported ?? false;

    if (fileSize == null &&
        !isEncrypted &&
        createdAt == DateTime.fromMillisecondsSinceEpoch(0)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatDate(createdAt),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            children: [
              if (isEncrypted)
                const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
              if (isEncrypted && fileSize != null) const SizedBox(width: 12),
              if (fileSize != null)
                Text(
                  formatFileSize(fileSize),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(GpsCoordinates gps) async {
    final lat = gps.latitude;
    final lon = gps.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开地图应用')));
      }
    }
  }

  Widget _buildGpsInfo(GpsCoordinates gps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: () => _openMap(gps),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Colors.white54,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${gps.latitude.toStringAsFixed(6)}, ${gps.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, color: Colors.white38, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildIntro(String intro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: Text(
        intro,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.6,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildBid(String bid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 36, top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BID',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            formatBid(bid),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace',
              letterSpacing: 0.8,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _isDownloading ? null : _handleDownload,
          icon: _isDownloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                )
              : const Icon(
                  Icons.download_outlined,
                  size: 16,
                  color: Colors.white54,
                ),
          label: Text(
            _isDownloading ? '下载中...' : '下载到本地',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }

  Future<void> _handleDownload() async {
    setState(() => _isDownloading = true);

    try {
      var result = _imageResult;
      if (result == null || result.variant != ImageVariant.original) {
        await _loadImage();
        result = _imageResult;
      }

      if (result == null || result.bytes.isEmpty) {
        _showMessage('没有可下载的图片');
        return;
      }

      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '选择保存位置',
        fileName: _downloadFileName(),
        type: FileType.custom,
        allowedExtensions: _allowedExtensions(),
      );

      if (outputFile == null) {
        _showMessage('取消下载');
        return;
      }

      await File(outputFile).writeAsBytes(result.bytes);
      _showMessage('文件已保存');
    } catch (error) {
      _showMessage('下载失败: $error');
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  String _downloadFileName() {
    final fileName =
        _data.fileName.trim().isEmpty ? '图片' : _data.fileName.trim();
    final extension = _data.extension;
    final hasExtension =
        extension.isNotEmpty && fileName.toLowerCase().endsWith('.$extension');
    final name =
        hasExtension ? fileName : '$fileName${extension.isEmpty ? '' : '.$extension'}';
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  List<String>? _allowedExtensions() {
    final extension = _data.extension;
    if (extension.isEmpty) {
      return null;
    }
    return [extension];
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  BlockImageResult? _createInitialResult(
    Uint8List bytes,
    ImageVariant variant,
  ) {
    if (bytes.isEmpty) {
      return null;
    }
    final cid = _data.cid ?? _data.bid;
    if (cid == null || cid.trim().isEmpty) {
      return BlockImageResult(
        bytes: bytes,
        variant: variant,
        provider: MemoryImage(bytes),
        source: ImageLoadSource.external,
      );
    }
    ImageCacheHelper.cacheMemoryImage(cid, bytes, variant: variant);
    unawaited(ImageCacheHelper.saveImageToCache(cid, bytes, variant: variant));
    unawaited(ImageCacheHelper.warmUpMemoryCache(cid, bytes, variant: variant));
    final sanitizedKey = ImageCacheHelper.composeKey(cid, variant);
    return BlockImageResult(
      bytes: bytes,
      variant: variant,
      provider: CidImageProvider(
        cid: sanitizedKey,
        bytesResolver: () async => bytes,
      ),
      source: ImageLoadSource.external,
    );
  }
}

/// 简单全屏图片查看页
class _FullScreenImagePage extends StatelessWidget {
  const _FullScreenImagePage({required this.imageResult});

  final BlockImageResult imageResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            child: Image(
              image: imageResult.provider,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
