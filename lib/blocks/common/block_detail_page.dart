import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters/bid_formatter.dart';
import '../../core/models/block_model.dart';
import 'package:block_app/core/network/api/block_api.dart';
import '../../features/link/pages/link_page.dart';
import '../../state/connection_provider.dart';
import '../../state/block_provider.dart';
import '../../components/block/widgets/block_header.dart';
import '../../components/block/widgets/block_meta_column.dart';
import '../../components/block/widgets/block_meta_tile.dart';
import '../../components/block/widgets/block_permission_card.dart';
import '../../components/block/widgets/block_quick_actions.dart';
import '../../components/block/widgets/block_section_header.dart';
import '../../components/block/raw_data_page.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';
import '../../core/routing/app_router.dart';

class BlockDetailPage extends StatefulWidget {
  const BlockDetailPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<BlockDetailPage> createState() => _BlockDetailPageState();
}

class _BlockDetailPageState extends State<BlockDetailPage> {
  late Map<String, dynamic> _blockData;
  bool _isAddingTag = false;
  bool _isSyncingLinkTag = false;
  VoidCallback? _blockProviderListener;

  @override
  void initState() {
    super.initState();
    _blockData = Map<String, dynamic>.from(widget.block.data);
    
    // Listen to BlockProvider for updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _blockProviderListener = _onBlockProviderUpdate;
        context.read<BlockProvider>().addListener(_blockProviderListener!);
        final bid = widget.block.bid;
        debugPrint('BlockDetailPage: Added BlockProvider listener for BID: $bid');
      }
    });
  }

  @override
  void dispose() {
    // Remove BlockProvider listener
    if (_blockProviderListener != null) {
      try {
        context.read<BlockProvider>().removeListener(_blockProviderListener!);
        debugPrint('BlockDetailPage: Removed BlockProvider listener');
      } catch (e) {
        debugPrint('BlockDetailPage: Error removing BlockProvider listener: $e');
      }
      _blockProviderListener = null;
    }
    super.dispose();
  }

  /// Handle BlockProvider updates
  void _onBlockProviderUpdate() {
    if (!mounted) return;
    
    final bid = widget.block.bid;
    if (bid == null || bid.isEmpty) return;
    
    try {
      final blockProvider = context.read<BlockProvider>();
      final updatedBlock = blockProvider.getBlock(bid);
      
      if (updatedBlock != null) {
        debugPrint('BlockDetailPage: Received updated Block from BlockProvider for BID: $bid');
        setState(() {
          _blockData = Map<String, dynamic>.from(updatedBlock.data);
        });
        debugPrint('BlockDetailPage: UI updated with latest Block data');
      }
    } catch (e) {
      debugPrint('BlockDetailPage: Error in _onBlockProviderUpdate: $e');
    }
  }

  BlockModel get _blockModel => BlockModel(data: _blockData);

  Color _getPermissionColor(int permission) {
    switch (permission) {
      case 0:
        return const Color(0xFFAB47BC);
      case 1:
        return const Color(0xFF4CAF50);
      case 2:
        return const Color(0xFF26C6DA);
      case 3:
        return const Color(0xFFFFB300);
      case 4:
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  String _describePermission(int permission) {
    switch (permission) {
      case 0:
        return '最高级别';
      case 1:
        return '开放访问，适合公开查看';
      case 2:
        return '团队共享，需要成员授权';
      case 3:
        return '受控访问，需特定权限';
      case 4:
        return '核心保密，仅限关键人员';
      default:
        return '访问级别未定义';
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = _blockModel;
    final name = block.maybeString('name');
    final intro = block.maybeString('intro');
    final bid = block.maybeString('bid');
    final model = block.maybeString('model');
    final tags = _resolveTags();
    final linkTags = _resolveLinkTags();
    final permissionLevel = block.maybeInt('permission_level') ?? 0;
    final ownerBid = block.maybeString('ownerBid');
    final addTime = _resolveAddTime();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: true,
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlockHeader(
                  name: name,
                  intro: intro,
                  tags: tags,
                  alwaysShowTags: true,
                  onAddTag: _isAddingTag ? null : () => _handleAddTag(context),
                  addTime: addTime,
                  quickActions: BlockQuickActions(
                    actions: const [
                      BlockQuickAction(
                        icon: Icons.dataset_outlined,
                        label: '原始数据',
                      ),
                      BlockQuickAction(
                        icon: Icons.link_outlined,
                        label: 'Link',
                      ),
                      BlockQuickAction(
                        icon: Icons.edit_note_outlined,
                        label: '修改',
                      ),
                      BlockQuickAction(
                        icon: Icons.delete_outline,
                        label: '删除',
                      ),
                    ],
                    onTap: (action) => _handleQuickActionTap(action, context),
                  ),
                ),
                const SizedBox(height: 28),
                _buildLinkTagSection(linkTags),
                const SizedBox(height: 28),
                const BlockSectionHeader(title: '块信息'),
                const SizedBox(height: 18),
                BlockMetaColumn(
                  fields: [
                    if (bid != null) BlockMetaField(label: 'BID', value: bid),
                    if (model != null)
                      BlockMetaField(label: 'MODEL', value: model),
                  ],
                ),
                const SizedBox(height: 36),
                const BlockSectionHeader(title: '权限'),
                const SizedBox(height: 18),
                BlockPermissionCard(
                  permissionLevel: permissionLevel.toString(),
                  color: _getPermissionColor(permissionLevel),
                  description: _describePermission(permissionLevel),
                ),
                if (ownerBid != null) ...[
                  const SizedBox(height: 16),
                  BlockMetaTile(label: '所有者 BID', value: ownerBid),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _resolveTags() {
    return _extractTags(_blockData);
  }

  List<String> _resolveLinkTags() {
    final linkTagValue = _blockData['link_tag'];
    if (linkTagValue is List) {
      return linkTagValue
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final alternative = _blockData['link_tags'];
    if (alternative is List) {
      return alternative
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  String? _resolveAddTime() {
    final addTimeValue = _blockData['add_time'];
    if (addTimeValue is DateTime) {
      return formatDate(addTimeValue);
    }
    if (addTimeValue is String && addTimeValue.trim().isNotEmpty) {
      return addTimeValue;
    }

    final createdAt = _blockModel.getDateTime('createdAt');
    if (createdAt != null) {
      return formatDate(createdAt);
    }
    return null;
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

  void _handleQuickActionTap(
    BlockQuickAction action,
    BuildContext context,
  ) async {
    final label = action.label;
    if (label == '原始数据') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RawDataPage(block: _blockModel)),
      );
      return;
    }

    if (label == 'Link') {
      final bid = _blockModel.maybeString('bid') ?? 'BID 未设置';
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => LinkPage(bid: bid)));
      return;
    }

    if (label == '修改') {
      final result = await AppRouter.openBlockEditPage(context, _blockModel);
      if (result != null && mounted) {
        setState(() {
          _blockData = Map<String, dynamic>.from(result.data);
        });
        
        // Update BlockProvider to notify all listening pages
        try {
          final blockProvider = context.read<BlockProvider>();
          blockProvider.updateBlock(result);
          debugPrint('BlockDetailPage: Updated BlockProvider after edit with BID: ${result.bid}');
        } catch (e) {
          debugPrint('BlockDetailPage: Error updating BlockProvider: $e');
        }
        
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('块已更新')));
      }
      return;
    }

    if (label == '删除') {
      await _handleDeleteBlock(context);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label 功能暂未实现')));
  }

  Future<void> _handleDeleteBlock(BuildContext context) async {
    final bid = _blockModel.maybeString('bid');
    final name = _blockModel.maybeString('name') ?? 'Block';
    
    if (bid == null || bid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法删除：BID 不存在')),
      );
      return;
    }

    // 显示删除确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: '删除确认',
        content: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '确定要删除 "$name" 吗？',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '此操作将删除：',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const Text(
                '• Block 本身\n• 所有相关的 Link（作为 main 或 target）\n• 所有相关的 Tag',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '此操作不可撤销！',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
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
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('删除'),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) {
      return;
    }

    // 执行删除操作
    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      
      await api.deleteBlock(bid: bid);
      
      if (!mounted) return;
      
      // 删除成功，显示提示并返回上一页
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Block 已删除')),
      );
      
      // 返回上一页
      Navigator.of(context).pop();
      
    } catch (error) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    }
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('标签不能为空')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标签已存在')));
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
      setState(() {
        _blockData = updatedData;
        _isAddingTag = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加标签')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAddingTag = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加失败：$error')));
    }
  }

  Future<void> _handleAddLinkTag(BuildContext context) async {
    if (_isSyncingLinkTag) {
      return;
    }

    final controller = TextEditingController();
    final dialogResult = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: '新增链接标签',
          content: AppDialogTextField(
            controller: controller,
            label: '链接标签名称',
            hintText: '请输入链接标签，例如：视频、证据',
          ),
          actions: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('链接标签不能为空')));
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    final trimmed = dialogResult?.trim() ?? '';
    if (trimmed.isEmpty) {
      return;
    }

    final current = _resolveLinkTags();
    if (current.contains(trimmed)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接标签已存在')));
      return;
    }

    final updatedTags = [...current, trimmed];
    final updatedData = Map<String, dynamic>.from(_blockData)
      ..['link_tag'] = updatedTags;
    if (updatedData.containsKey('link_tags')) {
      updatedData['link_tags'] = updatedTags;
    }

    setState(() => _isSyncingLinkTag = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      await api.saveBlock(
        data: updatedData,
        receiverBid: _resolveReceiverBidPrefix(),
      );
      if (!mounted) return;
      setState(() {
        _blockData = updatedData;
        _isSyncingLinkTag = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加链接标签')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSyncingLinkTag = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加失败：$error')));
    }
  }

  Future<void> _handleRemoveLinkTag(String tag) async {
    if (_isSyncingLinkTag) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: '删除链接标签',
        content: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            '确定删除链接标签 “$tag” 吗？',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) {
      return;
    }

    final current = _resolveLinkTags();
    final updatedTags = current.where((element) => element != tag).toList();
    final updatedData = Map<String, dynamic>.from(_blockData)
      ..['link_tag'] = updatedTags;
    if (updatedData.containsKey('link_tags')) {
      updatedData['link_tags'] = updatedTags;
    }

    setState(() => _isSyncingLinkTag = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      await api.saveBlock(
        data: updatedData,
        receiverBid: _resolveReceiverBidPrefix(),
      );
      if (!mounted) return;
      setState(() {
        _blockData = updatedData;
        _isSyncingLinkTag = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除链接标签')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSyncingLinkTag = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
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

  Widget _buildLinkTagSection(List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '链接标签',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              _LinkTagPill(
                label: tag,
                onRemove: () => _handleRemoveLinkTag(tag),
              ),
            _LinkTagAddButton(
              enabled: !_isSyncingLinkTag,
              onTap: _isSyncingLinkTag
                  ? null
                  : () => _handleAddLinkTag(context),
            ),
          ],
        ),
        if (_isSyncingLinkTag)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ),
      ],
    );
  }
}

class _LinkTagPill extends StatelessWidget {
  const _LinkTagPill({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white38,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTagAddButton extends StatelessWidget {
  const _LinkTagAddButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = enabled ? '+ 添加链接标签' : '正在同步…';
    final color = enabled ? Colors.white24 : Colors.white12;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: ShapeDecoration(
          shape: _DashedRectBorder(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white54 : Colors.white30,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _DashedRectBorder extends ShapeBorder {
  const _DashedRectBorder({
    required this.color,
    required this.borderRadius,
    this.dashWidth = 4,
    this.gapWidth = 3,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double dashWidth;
  final double gapWidth;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => this;

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => this;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => this;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    path.addRRect(borderRadius.toRRect(rect));
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final rrect = borderRadius.toRRect(rect);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        final extractPath = metric.extractPath(
          distance,
          next.clamp(0.0, metric.length),
        );
        canvas.drawPath(extractPath, paint);
        distance = next + gapWidth;
      }
    }
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();
}
