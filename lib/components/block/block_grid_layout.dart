import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../blocks/file/models/file_card_data.dart';
import '../../blocks/service/utils/service_decryptor.dart';
import '../../core/models/block_model.dart';
import 'package:block_app/core/network/api/block_api.dart';
import '../../features/link/pages/link_page.dart';
import '../../state/connection_provider.dart';
import '../../utils/block_image_loader.dart';
import '../../utils/file_category.dart';
import '../../core/storage/cache/image_cache.dart';
import '../../core/storage/cache/block_cache.dart';
import '../../core/utils/helpers/platform_helper.dart';
import '../../core/routing/app_router.dart';

class BlockGridLayout extends StatelessWidget {
  const BlockGridLayout({
    super.key,
    required this.blocks,
    this.padding = const EdgeInsets.all(16),
  });

  final List<BlockModel> blocks;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 100,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        return BlockGridItem(block: blocks[index]);
      },
    );
  }
}

class SliverBlockGrid extends StatelessWidget {
  const SliverBlockGrid({
    super.key,
    required this.blocks,
    this.onBlockLongPress,
  });

  final List<BlockModel> blocks;
  final void Function(BlockModel block)? onBlockLongPress;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 90,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return BlockGridItem(
            block: blocks[index],
            onLongPress: onBlockLongPress,
          );
        },
        childCount: blocks.length,
        addAutomaticKeepAlives: false,
      ),
    );
  }
}

class BlockGridItem extends StatefulWidget {
  const BlockGridItem({
    super.key,
    required this.block,
    this.onLongPress,
  });

  final BlockModel block;
  final void Function(BlockModel block)? onLongPress;

  @override
  State<BlockGridItem> createState() => _BlockGridItemState();
}

class _BlockGridItemState extends State<BlockGridItem> {
  String? _decryptedTitle;
  String? _decryptedName;

  @override
  void initState() {
    super.initState();
    _checkServiceDecryption();
  }

  Future<void> _checkServiceDecryption() async {
    final model = widget.block.maybeString('model') ?? 'unknown';
    // 只对服务类型进行解密
    if (model != '81b0bc8db4f678300d199f5b34729282') return;

    final isEncrypted = ServiceDecryptor.isEncrypted(widget.block);
    if (!isEncrypted) return;

    final result = await ServiceDecryptor.tryDecrypt(widget.block);
    if (result != null && mounted) {
      setState(() {
        _decryptedTitle = result.data['name'] as String?;
        _decryptedName = result.data['name'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final model = widget.block.maybeString('model') ?? 'unknown';
    final title = _decryptedTitle ?? widget.block.maybeString('name');
    final name = _decryptedName ?? widget.block.maybeString('name');
    final bid = widget.block.maybeString('bid') ?? '';

    String displayText;
    if (title != null && title.isNotEmpty) {
      displayText = title;
    } else if (name != null && name.isNotEmpty) {
      displayText = name;
    } else {
      displayText = _truncateBid(bid);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => AppRouter.openBlockDetailPage(context, widget.block),
      onLongPress: widget.onLongPress != null
          ? () => widget.onLongPress?.call(widget.block)
          : null,
      onSecondaryTapDown: PlatformHelper.isMacOS
          ? (details) => _onSecondaryTapDown(context, details)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildIcon(context, model),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _onSecondaryTapDown(BuildContext context, TapDownDetails details) {
    if (!PlatformHelper.isMacOS) return;
    _showMacContextMenu(context, details.globalPosition);
  }

  Future<void> _showMacContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context);
    final overlayRenderBox =
        overlay?.context.findRenderObject() as RenderBox?;
    if (overlayRenderBox == null) {
      return;
    }

    final localOffset = overlayRenderBox.globalToLocal(globalPosition);
    final menuPosition = RelativeRect.fromLTRB(
      localOffset.dx,
      localOffset.dy,
      overlayRenderBox.size.width - localOffset.dx,
      overlayRenderBox.size.height - localOffset.dy,
    );

    final selection = await showMenu<_BlockContextMenuAction>(
      context: context,
      position: menuPosition,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      color: const Color(0xF01C1C1E),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black54,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      items: [
        PopupMenuItem(
          value: _BlockContextMenuAction.copyBid,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: Colors.purple.shade300),
              const SizedBox(width: 10),
              const Text(
                '复制 BID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: _BlockContextMenuAction.link,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.link, size: 18, color: Colors.blue.shade300),
              const SizedBox(width: 10),
              const Text(
                '链接',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: _BlockContextMenuAction.externalLink,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 18, color: Colors.teal.shade300),
              const SizedBox(width: 10),
              const Text(
                '外链',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: _BlockContextMenuAction.addToOtherBlock,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.add_box_outlined, size: 18, color: Colors.orange.shade300),
              const SizedBox(width: 10),
              const Text(
                '添加到其它块',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (selection == null) return;
    _handleContextMenuAction(context, selection);
  }

  void _handleContextMenuAction(
    BuildContext context,
    _BlockContextMenuAction action,
  ) {
    switch (action) {
      case _BlockContextMenuAction.link:
        _openLinkPage(context, 0);
        break;
      case _BlockContextMenuAction.externalLink:
        _openLinkPage(context, 1);
        break;
      case _BlockContextMenuAction.addToOtherBlock:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添加到其它块功能暂未实现')),
        );
        break;
      case _BlockContextMenuAction.copyBid:
        _copyBidToClipboard(context);
        break;
    }
  }

  void _openLinkPage(BuildContext context, int initialIndex) {
    final bid = widget.block.maybeString('bid');
    if (bid == null || bid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前块缺少 BID 信息')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LinkPage(bid: bid, initialIndex: initialIndex),
      ),
    );
  }

  void _copyBidToClipboard(BuildContext context) {
    final bid = widget.block.maybeString('bid');
    if (bid == null || bid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前块缺少 BID 信息')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: bid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 BID: $bid'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, String model) {
    switch (model) {
      case '1635e536a5a331a283f9da56b7b51774': // 集合
        return const Center(
          child: Icon(Icons.folder, color: Colors.blueAccent, size: 48),
        );
      case '93b133932057a254cc15d0f09c91ca98': // 文档
        return const Center(
          child: Icon(Icons.description, color: Colors.white70, size: 48),
        );
      case 'c4238dd0d3d95db7b473adb449f6d282': // 文件
        return _buildFileIcon();
      case '52da1e115d0a764b43c90f6b43284aa9': // 文章
        return const Center(
          child: Icon(Icons.article, color: Colors.white70, size: 48),
        );
      case '81b0bc8db4f678300d199f5b34729282': // 服务
        return _BlockServiceWidget(block: widget.block);
      case '71b6eb41f026842b3df6b126dfe11c29': // 用户
        return _BlockUserAvatarWidget(block: widget.block);
      case '34c00af3a2d32129327766285361b0c1': // 通用
        return const Center(
          child: Icon(Icons.apps, color: Colors.white70, size: 48),
        );
      default:
        return const Center(
          child: Icon(Icons.help_outline, color: Colors.white24, size: 48),
        );
    }
  }

  Widget _buildFileIcon() {
    final ipfs = widget.block.map('ipfs');
    final ext = ipfs['ext'] as String?;
    final rawExtension = ext?.toLowerCase() ?? '';
    final extension = rawExtension.startsWith('.') ? rawExtension : '.$rawExtension';

    // 根据扩展名返回不同的图标
    switch (extension) {
      // 图片文件
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
      case '.svg':
        return _BlockImageWidget(block: widget.block);

      // 视频文件
      case '.mp4':
      case '.avi':
      case '.mov':
      case '.wmv':
      case '.flv':
      case '.mkv':
        return const Center(
          child: Icon(Icons.movie, color: Colors.purpleAccent, size: 48),
        );

      // 音频文件
      case '.mp3':
      case '.wav':
      case '.aac':
      case '.flac':
      case '.ogg':
        return const Center(
          child: Icon(Icons.audiotrack, color: Colors.greenAccent, size: 48),
        );

      // 文档文件
      case '.pdf':
        return const Center(
          child: Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 48),
        );
      case '.doc':
      case '.docx':
        return const Center(
          child: Icon(Icons.article, color: Colors.blueAccent, size: 48),
        );
      case '.xls':
      case '.xlsx':
        return const Center(
          child: Icon(Icons.table_chart, color: Colors.greenAccent, size: 48),
        );
      case '.ppt':
      case '.pptx':
        return const Center(
          child: Icon(Icons.slideshow, color: Colors.orangeAccent, size: 48),
        );
      case '.txt':
        return const Center(
          child: Icon(Icons.text_snippet, color: Colors.white70, size: 48),
        );

      // 压缩文件
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return const Center(
          child: Icon(Icons.archive, color: Colors.amber, size: 48),
        );

      // 默认文件图标
      default:
        return const Center(
          child: Icon(Icons.insert_drive_file, color: Colors.white70, size: 48),
        );
    }
  }

  String _truncateBid(String bid) {
    if (bid.length <= 8) return bid;
    return '${bid.substring(0, 4)}...${bid.substring(bid.length - 4)}';
  }
}

enum _BlockContextMenuAction {
  link,
  externalLink,
  addToOtherBlock,
  copyBid,
}

class _BlockImageWidget extends StatefulWidget {
  const _BlockImageWidget({required this.block});

  final BlockModel block;

  @override
  State<_BlockImageWidget> createState() => _BlockImageWidgetState();
}

class _BlockImageWidgetState extends State<_BlockImageWidget> {
  BlockImageResult? _imageResult;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void didUpdateWidget(_BlockImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.maybeString('bid') !=
        widget.block.maybeString('bid')) {
      _loadImage();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final connection = Provider.of<ConnectionProvider>(context, listen: false);
      final endpoint = connection.ipfsEndpoint ?? '';
      final data = FileCardData.fromBlock(widget.block);

      final result = await BlockImageLoader.instance.loadVariant(
        data: data,
        variant: ImageVariant.small,
        endpoint: endpoint,
      );

      if (mounted) {
        setState(() {
          _imageResult = result;
          _isLoading = false;
        });
      }
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

    if (_hasError || _imageResult == null) {
      return const Center(
        child: Icon(Icons.image, color: Colors.white38, size: 32),
      );
    }

    return Image(
      image: _imageResult!.provider,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

class _BlockServiceWidget extends StatelessWidget {
  const _BlockServiceWidget({required this.block});

  final BlockModel block;

  @override
  Widget build(BuildContext context) {
    final isEncrypted = ServiceDecryptor.isEncrypted(block);
    
    return Stack(
      fit: StackFit.expand,
      children: [
        const Center(
          child: Icon(Icons.settings, color: Colors.orangeAccent, size: 48),
        ),
        if (isEncrypted)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white70,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _BlockUserAvatarWidget extends StatefulWidget {
  const _BlockUserAvatarWidget({required this.block});

  final BlockModel block;

  @override
  State<_BlockUserAvatarWidget> createState() => _BlockUserAvatarWidgetState();
}

class _BlockUserAvatarWidgetState extends State<_BlockUserAvatarWidget> {
  ImageProvider? _avatarProvider;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void didUpdateWidget(_BlockUserAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldAvatarBid = oldWidget.block.maybeString('avatar_bid')?.trim();
    final newAvatarBid = widget.block.maybeString('avatar_bid')?.trim();
    if (oldAvatarBid != newAvatarBid) {
      if (newAvatarBid != null && newAvatarBid.isNotEmpty) {
        _loadAvatar(newAvatarBid);
      } else {
        setState(() {
          _avatarProvider = null;
          _isLoading = false;
          _hasError = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final avatarBid = widget.block.maybeString('avatar_bid')?.trim();
    if (avatarBid != null && avatarBid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAvatar(avatarBid));
    }
  }

  Future<void> _loadAvatar(String bid) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _avatarProvider = null;
    });

    try {
      final connection = Provider.of<ConnectionProvider>(context, listen: false);
      final endpoint = connection.ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        throw Exception('未配置 IPFS 节点');
      }

      // 1. 先尝试从缓存获取 Block 元数据
      BlockModel? avatarBlock = await BlockCache.instance.get(bid);
      
      // 2. 如果缓存未命中，从 API 获取并缓存
      if (avatarBlock == null) {
        final api = BlockApi(connectionProvider: connection);
        final response = await api.getBlock(bid: bid);
        final data = response['data'];
        if (data is! Map<String, dynamic> || data.isEmpty) {
          throw Exception('头像对应的 Block 数据为空');
        }

        avatarBlock = BlockModel(data: data);
        
        // 保存到缓存
        await BlockCache.instance.put(bid, avatarBlock);
      }

      final fileData = FileCardData.fromBlock(avatarBlock);
      final category = resolveFileCategory(fileData.extension);
      if (!category.isImage) {
        throw Exception('头像 Block 不是图片类型');
      }
      final cid = fileData.cid;
      if (cid == null || cid.isEmpty) {
        throw Exception('头像缺少 CID');
      }

      final result = await BlockImageLoader.instance.loadVariant(
        data: fileData,
        endpoint: endpoint,
        variant: ImageVariant.small,
      );

      if (!mounted) return;
      setState(() {
        _avatarProvider = result.provider;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_avatarProvider != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: _avatarProvider!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '用户',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      );
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

    return Center(
      child: Icon(
        _hasError ? Icons.broken_image_outlined : Icons.person_outline,
        color: Colors.white38,
        size: 32,
      ),
    );
  }
}
