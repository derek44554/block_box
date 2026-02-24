import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/models/block_model.dart';
import '../../../core/network/api/block_api.dart';
import '../../common/block_detail_page.dart';
import '../../../state/connection_provider.dart';
import '../../../state/block_detail_listener_mixin.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../utils/ipfs_file_helper.dart';
import '../../../utils/block_image_loader.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/widgets/common/tag_widget.dart';
import '../../../core/routing/app_router.dart';
import '../../file/models/file_card_data.dart';

// 文章详情页面
class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> with BlockDetailListenerMixin {
  late FileCardData _fileData;
  bool _isLoadingContent = false;
  bool _isDownloading = false;
  String? _loadError;
  String? _markdownContent;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _fileData = FileCardData.fromBlock(updatedBlock);
    });
    // Reload content if CID changed
    _loadMarkdownContent();
  }

  @override
  void initState() {
    super.initState();
    _fileData = FileCardData.fromBlock(widget.block);
    startBlockProviderListener();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMarkdownContent());
  }

  @override
  void dispose() {
    stopBlockProviderListener();
    super.dispose();
  }

  Future<void> _loadMarkdownContent() async {
    final cid = _fileData.cid;
    if (cid == null || cid.isEmpty) {
      setState(() {
        _loadError = '缺少文章内容的 CID';
        _markdownContent = null;
      });
      return;
    }

    setState(() {
      _isLoadingContent = true;
      _loadError = null;
    });

    try {
      final provider = context.read<ConnectionProvider>();
      final endpoint = provider.ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        throw Exception('缺少 IPFS 地址，无法加载文章内容');
      }

      final bytes = await IpfsFileHelper.loadRawByCid(endpoint: endpoint, data: _fileData);
      final content = utf8.decode(bytes, allowMalformed: true);

      if (!mounted) return;
      setState(() {
        _markdownContent = content;
        _isLoadingContent = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = '加载文章失败：$error';
        _markdownContent = null;
        _isLoadingContent = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _loadMarkdownContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.black,
      ),
      body: _buildArticleDetailPage(),
    );
  }

  Widget _buildArticleDetailPage() {
    final intro = widget.block.maybeString('intro');
    final cover = widget.block.maybeString('cover');
    final name = widget.block.maybeString('name');
    final bid = widget.block.maybeString('bid');
    final tags = widget.block.getList<String>('tag');

    return Container(
      color: Colors.black,
      child: RefreshIndicator(
        onRefresh: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlockDetailPage(block: widget.block),
            ),
          );
          await _handleRefresh();
        },
        color: Colors.white,
        backgroundColor: Colors.grey.shade900,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // 如果有封面，使用封面+标题的组合布局
            if (cover != null && cover.isNotEmpty)
              _buildCoverWithTitle(cover, name)
            else ...[
              // 没有封面时使用原有的头部布局
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    if (name != null) _buildTitleSection(name),
                  ]),
                ),
              ),
            ],
            
            // 黑色背景条（仅在有封面时显示）
            if (cover != null && cover.isNotEmpty)
              _buildBlackDivider(),
            
            // 其余内容
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (intro != null) _buildIntro(intro),
                  _buildMarkdownSection(),
                  if (tags.isNotEmpty) _buildTags(tags),
                  if (bid != null) _buildBid(bid),
                  if (_markdownContent != null) _buildDownloadSection(),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownSection() {
    if (_isLoadingContent) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }

    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          _loadError!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }

    final content = _markdownContent;
    if (content == null || content.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '暂无正文内容',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    // 处理内容，移除第一个 # 标题
    final processedContent = _removeFirstH1Title(content);

    final theme = Theme.of(context);
    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.7, fontSize: 15),
      h1: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
      h2: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
      h3: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white24, width: 3)),
      ),
      blockquote: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
      code: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
      codeblockDecoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.6),
      ),
      listBullet: const TextStyle(color: Colors.white70),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: MarkdownBody(
        data: processedContent,
        styleSheet: styleSheet,
        selectable: true,
        imageBuilder: (uri, title, alt) => _buildCustomImage(uri, title, alt),
        onTapLink: (text, href, title) {
          if (href != null) {
            _handleLinkTap(href);
          }
        },
        softLineBreak: true,
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
              '文章',
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

  Widget _buildCoverWithTitle(String coverBid, String? title) {
    // 验证BID格式
    if (!_isBidFormat(coverBid)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final addTime = widget.block.getDateTime('add_time');

    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // 封面图片
          _CoverImageWidget(coverBid: coverBid, showFileName: false),
          
          // 标题覆盖层
          if (title != null && title.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 文章标签和时间
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            '文章',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        if (addTime != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              _formatDisplayTime(addTime),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 文章标题
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlackDivider() {
    return SliverToBoxAdapter(
      child: Container(
        height: 8,
        color: Colors.black,
      ),
    );
  }

  Widget _buildTitleSection(String title) {
    final addTime = widget.block.getDateTime('add_time');
    
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间显示（如果有的话）
          if (addTime != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
              child: Text(
                _formatDisplayTime(addTime),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // 标题
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildIntro(String intro) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 40),
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

  Widget _buildTags(List<String> tags) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '标签',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          TagWidget(tags: tags),
        ],
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
              color: Colors.white.withValues(alpha: 0.6),
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
      margin: const EdgeInsets.only(top: 24, bottom: 24),
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
    if (_markdownContent == null || _markdownContent!.isEmpty) {
      _showMessage('没有可下载的内容');
      return;
    }

    setState(() => _isDownloading = true);

    try {
      // 生成默认文件名
      final fileName = _generateFileName();

      // 使用系统文件选择器让用户选择保存位置
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '选择保存位置',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['md'],
      );

      if (outputFile == null) {
        _showMessage('取消下载');
        return;
      }

      // 写入文件
      final file = File(outputFile);
      await file.writeAsString(_markdownContent!, encoding: utf8);

      _showMessage('文件已保存');
    } catch (e) {
      debugPrint('文章下载失败: $e');
      _showMessage('下载失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  String _generateFileName() {
    final name = widget.block.maybeString('name') ?? '文章';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // 清理文件名，移除不合法字符
    final cleanName = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    
    return '${cleanName}_$timestamp.md';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildCustomImage(Uri uri, String? title, String? alt) {
    final uriString = uri.toString();
    
    // 检查是否是BID格式（32位十六进制字符串）
    if (_isBidFormat(uriString)) {
      return _BidImageWidget(
        bid: uriString,
        title: title,
        alt: alt,
      );
    }
    
    // 普通网络图片
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 400, // 限制最大高度
      ),
      child: Image.network(
        uriString,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  alt ?? title ?? '图片加载失败',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isBidFormat(String text) {
    // BID格式：32位十六进制字符串
    return RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(text);
  }

  /// 移除Markdown内容中的第一个H1标题
  String _removeFirstH1Title(String content) {
    final lines = content.split('\n');
    final processedLines = <String>[];
    bool foundFirstH1 = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // 检查是否是H1标题（以 # 开头，但不是 ## 或更多）
      if (!foundFirstH1 && RegExp(r'^#\s+').hasMatch(line)) {
        // 找到第一个H1标题，跳过这一行
        foundFirstH1 = true;
        
        // 如果下一行是空行，也跳过（通常H1标题后会有空行）
        if (i + 1 < lines.length && lines[i + 1].trim().isEmpty) {
          i++; // 跳过下一行
        }
        continue;
      }
      
      processedLines.add(line);
    }

    return processedLines.join('\n');
  }

  /// 格式化显示时间
  String _formatDisplayTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // 如果是今天
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    }
    
    // 如果是昨天
    if (difference.inDays == 1) {
      return '昨天';
    }
    
    // 如果是一周内
    if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    }
    
    // 如果是今年
    if (dateTime.year == now.year) {
      return '${dateTime.month}月${dateTime.day}日';
    }
    
    // 其他情况显示完整日期
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日';
  }

  /// 处理链接点击事件
  Future<void> _handleLinkTap(String href) async {
    // 检查是否是BID格式的链接（32位十六进制字符串）
    if (_isBidFormat(href)) {
      await _navigateToBidBlock(href);
    } else {
      // 普通链接，显示提示信息
      _showMessage('链接：$href');
    }
  }

  /// 通过BID导航到对应的Block详情页
  Future<void> _navigateToBidBlock(String bid) async {
    try {
      // 显示加载提示
      _showMessage('正在加载...');

      // 通过BID获取block
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      final response = await api.getBlock(bid: bid);

      final data = response['data'];
      if (data == null || data is! Map<String, dynamic> || data.isEmpty) {
        throw Exception('Block数据为空');
      }

      final block = BlockModel(data: data);
      
      // 导航到Block详情页
      if (mounted) {
        await AppRouter.openBlockDetailPage(context, block);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('无法打开链接：$e');
      }
    }
  }

}

class _BidImageWidget extends StatefulWidget {
  const _BidImageWidget({
    required this.bid,
    this.title,
    this.alt,
  });

  final String bid;
  final String? title;
  final String? alt;

  @override
  State<_BidImageWidget> createState() => _BidImageWidgetState();
}

class _BidImageWidgetState extends State<_BidImageWidget> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImageFromBid();
  }

  Future<void> _loadImageFromBid() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 通过BID获取block
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      final response = await api.getBlock(bid: widget.bid);

      final data = response['data'];
      if (data == null || data is! Map<String, dynamic> || data.isEmpty) {
        throw Exception('Block数据为空');
      }

      final block = BlockModel(data: data);
      final fileData = FileCardData.fromBlock(block);

      // 检查是否是图片文件
      if (!_isImageFile(fileData.ipfsExt)) {
        throw Exception('不是图片文件');
      }

      // 使用BlockImageLoader加载图片内容（支持缓存）
      final endpoint = provider.ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        throw Exception('缺少IPFS地址');
      }

      final result = await BlockImageLoader.instance.loadVariant(
        data: fileData,
        endpoint: endpoint,
        variant: ImageVariant.medium,
      );

      if (mounted) {
        setState(() {
          _imageBytes = result.bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _isImageFile(String? extension) {
    if (extension == null) return false;
    final ext = extension.toLowerCase().replaceAll('.', '');
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '加载图片中...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              widget.alt ?? widget.title ?? '图片加载失败',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'BID: ${widget.bid}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_imageBytes != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(
          maxHeight: 400, // 限制最大高度
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _imageBytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.alt ?? widget.title ?? '图片显示失败',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _CoverImageWidget extends StatefulWidget {
  const _CoverImageWidget({required this.coverBid, this.showFileName = true});

  final String coverBid;
  final bool showFileName;

  @override
  State<_CoverImageWidget> createState() => _CoverImageWidgetState();
}

class _CoverImageWidgetState extends State<_CoverImageWidget> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _imageBytes;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _loadCoverImage();
  }

  Future<void> _loadCoverImage() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 通过BID获取block
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      final response = await api.getBlock(bid: widget.coverBid);

      final data = response['data'];
      if (data == null || data is! Map<String, dynamic> || data.isEmpty) {
        throw Exception('封面图片Block数据为空');
      }

      final block = BlockModel(data: data);
      final fileData = FileCardData.fromBlock(block);
      _fileName = block.maybeString('name') ?? '封面图片';

      // 检查是否是图片文件
      if (!_isImageFile(fileData.ipfsExt)) {
        throw Exception('封面不是图片文件');
      }

      // 使用BlockImageLoader加载图片内容（支持缓存）
      final endpoint = provider.ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        throw Exception('缺少IPFS地址');
      }

      final result = await BlockImageLoader.instance.loadVariant(
        data: fileData,
        endpoint: endpoint,
        variant: ImageVariant.medium,
      );

      if (mounted) {
        setState(() {
          _imageBytes = result.bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _isImageFile(String? extension) {
    if (extension == null) return false;
    final ext = extension.toLowerCase().replaceAll('.', '');
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white54,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '加载封面中...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: 160,
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Colors.white.withValues(alpha: 0.4),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              '封面加载失败',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'BID: ${widget.coverBid}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_imageBytes != null) {
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: widget.showFileName ? 200 : 250,
          maxHeight: widget.showFileName ? 300 : 350,
        ),
        decoration: BoxDecoration(
          borderRadius: widget.showFileName ? BorderRadius.circular(20) : BorderRadius.zero,
          boxShadow: widget.showFileName ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ] : null,
        ),
        child: ClipRRect(
          borderRadius: widget.showFileName ? BorderRadius.circular(20) : BorderRadius.zero,
          child: Stack(
            children: [
              // 主图片
              Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: widget.showFileName ? 200 : 300,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: widget.showFileName ? BorderRadius.circular(20) : BorderRadius.zero,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '图片显示失败',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // 渐变遮罩（可选，用于更好的视觉效果）
              if (widget.showFileName)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                ),
              // 文件名标签（可选）
              if (widget.showFileName && _fileName != null)
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      _fileName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
