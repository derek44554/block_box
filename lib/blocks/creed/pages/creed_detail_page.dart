import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/models/block_model.dart';
import '../../../core/network/api/block_api.dart';
import '../../../state/connection_provider.dart';
import '../../../state/block_provider.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/widgets/common/tag_widget.dart';
import '../../common/block_detail_page.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../state/block_detail_listener_mixin.dart';

/// 信条详情页面
///
/// 显示信条的完整内容，包括content和intro字段
class CreedDetailPage extends StatefulWidget {
  const CreedDetailPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<CreedDetailPage> createState() => _CreedDetailPageState();
}

class _CreedDetailPageState extends State<CreedDetailPage> with BlockDetailListenerMixin {
  late Map<String, dynamic> _blockData;
  bool _isAddingTag = false;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _blockData = Map<String, dynamic>.from(updatedBlock.data);
    });
  }

  @override
  void initState() {
    super.initState();
    _blockData = Map<String, dynamic>.from(widget.block.data);
    startBlockProviderListener();
  }

  @override
  void dispose() {
    stopBlockProviderListener();
    super.dispose();
  }

  BlockModel get _blockModel => BlockModel(data: _blockData);

  @override
  Widget build(BuildContext context) {
    final block = _blockModel;
    final content = block.maybeString('content') ?? '无内容';
    final intro = block.maybeString('intro');
    final bid = block.maybeString('bid');
    final tags = _resolveTags();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(toolbarHeight: 0),
        body: Container(
          color: Colors.black,
          child: RefreshIndicator(
            onRefresh: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlockDetailPage(block: _blockModel),
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
                      _buildContent(content),
                      if (intro != null && intro.isNotEmpty) _buildIntro(intro),
                      if (tags.isNotEmpty) _buildTags(tags),
                      if (bid != null) _buildBid(bid),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2D4A22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.format_quote,
              color: Color(0xFF4CAF50),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4CAF50), width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '信条',
              style: TextStyle(
                color: Color(0xFF4CAF50),
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

  Widget _buildContent(String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '信条内容',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111112),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(String intro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '简介',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111112),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            child: Text(
              intro,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(List<String> tags) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '标签',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _isAddingTag ? null : () => _handleAddTag(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Text(
                    _isAddingTag ? '添加中...' : '+ 添加',
                    style: TextStyle(
                      color: _isAddingTag ? Colors.white30 : Colors.white54,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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

  List<String> _resolveTags() {
    return _extractTags(_blockData);
  }

  List<String> _extractTags(Map<String, dynamic> data) {
    final tagValue = data['tag'];
    if (tagValue is List) {
      return tagValue
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final tagsValue = data['tags'];
    if (tagsValue is List) {
      return tagsValue
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String? _resolveReceiverBidPrefix() {
    final owner = _blockModel.maybeString('ownerBid');
    if (owner != null && owner.length >= 10) {
      return owner.substring(0, 10);
    }
    final bid = _blockModel.maybeString('bid');
    if (bid != null && bid.length >= 10) {
      return bid.substring(0, 10);
    }
    return null;
  }

  Future<void> _handleAddTag(BuildContext context) async {
    final controller = TextEditingController();
    final newTag = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: '添加标签',
          content: AppDialogTextField(
            controller: controller,
            label: '标签名称',
            hintText: '请输入标签名称',
          ),
          actions: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
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
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('标签不能为空')),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (newTag == null || newTag.trim().isEmpty) {
      return;
    }

    final tagValue = newTag.trim();
    final currentTags = List<String>.from(_resolveTags());
    if (currentTags.contains(tagValue)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标签已存在')),
      );
      return;
    }

    final updatedTags = [...currentTags, tagValue];
    final updatedData = Map<String, dynamic>.from(_blockData);
    final bid = _blockModel.maybeString('bid');
    if (bid != null && bid.isNotEmpty) {
      updatedData['bid'] = bid;
    }
    updatedData['tag'] = updatedTags;
    if (updatedData.containsKey('tags')) {
      updatedData['tags'] = updatedTags;
    }

    setState(() => _isAddingTag = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      await api.saveBlock(
        data: updatedData,
        receiverBid: _resolveReceiverBidPrefix(),
      );
      if (!mounted) return;
      
      // Update BlockProvider to notify all listening pages
      final blockProvider = context.read<BlockProvider>();
      blockProvider.updateBlock(BlockModel(data: Map<String, dynamic>.from(updatedData)));
      
      setState(() {
        _blockData = updatedData;
        _isAddingTag = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已添加标签')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAddingTag = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败：$error')),
      );
    }
  }
}