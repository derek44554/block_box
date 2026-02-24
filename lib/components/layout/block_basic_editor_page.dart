import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/block_model.dart';
import 'package:block_app/core/network/models/connection_model.dart';
import 'package:block_app/core/network/api/block_api.dart';
import '../../features/link/widgets/add_link_dialog.dart';
import '../block/widgets/block_permission_card.dart';
import '../block/widgets/block_section_header.dart';
import '../../state/connection_provider.dart';
import '../../core/utils/formatters/bid_formatter.dart';
import '../../core/utils/generators/bid_generator.dart';

/// 封装标签、权限、链接、BID 编辑功能的通用页面。
class BlockBasicEditorPage extends StatefulWidget {
  const BlockBasicEditorPage({
    super.key,
    required this.initialData,
    this.allowNodeSelection = false,
  });

  final BlockModel initialData;
  final bool allowNodeSelection;

  static String generateBidSafe(
    BuildContext context, {
    String? nodeBid,
  }) {
    final provider = context.read<ConnectionProvider>();
    final resolvedNodeBid = nodeBid ?? provider.activeNodeData?['sender'] as String?;

    if (resolvedNodeBid == null || resolvedNodeBid.length < 10) {
      throw StateError('无法获取有效的节点BID，当前节点BID: $resolvedNodeBid');
    }

    return generateBidV2(resolvedNodeBid);
  }

  static Future<BlockModel?> show(
    BuildContext context, {
    required BlockModel initialData,
    bool allowNodeSelection = false,
  }) {
    return Navigator.of(context).push<BlockModel>(
      MaterialPageRoute(
        builder: (_) => BlockBasicEditorPage(
          initialData: initialData,
          allowNodeSelection: allowNodeSelection,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<BlockBasicEditorPage> createState() => _BlockBasicEditorPageState();
}

class _BlockBasicEditorPageState extends State<BlockBasicEditorPage> {
  late final TextEditingController _bidController;
  final ScrollController _scrollController = ScrollController();

  late List<String> _tags;
  late List<String> _linkTags;
  late List<String> _links;
  late int _permissionLevel;

  bool _isProcessingLink = false;
  String? _selectedNodeBid;
  String? _selectedNodeName;
  String? _selectedNodeAddress;
  String? _bidSourceNodeBid;

  bool get _requiresNodeSelection => widget.allowNodeSelection;

  bool get _hasNodeSelection => (_selectedNodeBid?.length ?? 0) >= 10;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _bidController = TextEditingController(text: data.maybeString('bid') ?? '');
    _tags = data.list<String>('tag');
    _linkTags = data.list<String>('link_tag');
    _links = data.list<String>('link');
    _permissionLevel = data.maybeInt('permission_level') ?? 0;
    _selectedNodeBid = data.maybeString('node_bid');
    _selectedNodeName = data.maybeString('node_name');
    _selectedNodeAddress = data.maybeString('node_connection_address');
    _bidSourceNodeBid = _selectedNodeBid;

    if ((_bidController.text.trim().isEmpty) &&
        _selectedNodeBid != null &&
        _selectedNodeBid!.length >= 10) {
      _bidController.text = generateBidV2(_selectedNodeBid!);
    }
  }

  @override
  void dispose() {
    _bidController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleAddTagDialog(BuildContext context) async {
    final controller = TextEditingController();
    final newTag = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            '添加标签',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '请输入标签名称',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF232327),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white60),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('标签不能为空')),
                  );
                  return;
                }
                if (_tags.contains(value)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('标签已存在')),
                  );
                  return;
                }
                if (_tags.length >= 16) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('最多添加 16 个标签')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );

    if (newTag == null || newTag.trim().isEmpty) return;

    setState(() => _tags.add(newTag.trim()));
  }

  void _handleRemoveTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _handleAddLinkTagDialog(BuildContext context) async {
    final controller = TextEditingController();
    final newTag = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            '添加链接标签',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '请输入链接标签，例如：视频、证据',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF232327),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white60),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('链接标签不能为空')),
                  );
                  return;
                }
                if (_linkTags.contains(value)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('链接标签已存在')),
                  );
                  return;
                }
                if (_linkTags.length >= 16) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('最多添加 16 个链接标签')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );

    if (newTag == null || newTag.trim().isEmpty) return;

    setState(() => _linkTags.add(newTag.trim()));
  }

  void _handleRemoveLinkTag(String tag) {
    setState(() => _linkTags.remove(tag));
  }

  Future<void> _handleAddLink() async {
    if (_isProcessingLink) {
      return;
    }
    final newBid = await showAddLinkDialog(context);
    if (newBid == null) {
      return;
    }

    final trimmed = newBid.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('BID 不能为空')));
      return;
    }
    if (_links.contains(trimmed)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该链接已存在')));
      return;
    }
    final ownerBid = _bidController.text.trim();
    if (ownerBid.isNotEmpty && ownerBid == trimmed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('不能添加自身 BID')));
      return;
    }

    setState(() => _isProcessingLink = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      final response = await api.getBlock(bid: trimmed);
      final data = response['data'];
      if (data == null || data is! Map<String, dynamic> || data.isEmpty) {
        throw Exception('未找到指定 BID 对应的块');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _links.add(trimmed);
        _isProcessingLink = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接已添加')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isProcessingLink = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加失败：$error')));
    }
  }

  void _handleRemoveLink(String bid) {
    setState(() => _links.remove(bid));
  }

  void _ensureBidForNode(String nodeBid) {
    if (nodeBid.length < 10) {
      return;
    }
    _bidController.text = generateBidV2(nodeBid);
    _bidSourceNodeBid = nodeBid;
  }

  void _showNodeSelectionHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请选择用于创建的节点')),
    );
  }

  String? _extractNodeBid(ConnectionModel connection) {
    final sender = connection.nodeData?['sender'];
    if (sender is String && sender.length >= 10) {
      return sender;
    }
    return null;
  }

  Future<void> _handlePickNode() async {
    final provider = context.read<ConnectionProvider>();
    final nodes = provider.connections
        .where((connection) => _extractNodeBid(connection) != null)
        .toList();

    if (nodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可选择的节点，请先在连接设置中添加')),
      );
      return;
    }

    final result = await showModalBottomSheet<ConnectionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NodePickerSheet(
        nodes: nodes,
        initialAddress: _selectedNodeAddress,
        initialNodeBid: _selectedNodeBid,
      ),
    );

    if (result == null) {
      return;
    }

    final nodeBid = _extractNodeBid(result);
    if (nodeBid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所选节点缺少 BID 信息')),
      );
      return;
    }

    setState(() {
      _selectedNodeBid = nodeBid;
      _selectedNodeName = result.name;
      _selectedNodeAddress = result.address;
      _ensureBidForNode(nodeBid);
    });
  }

  void _handleComplete() {
    if (_isProcessingLink) {
      return;
    }

    if (_requiresNodeSelection && !_hasNodeSelection) {
      _showNodeSelectionHint();
      return;
    }

    if (_hasNodeSelection && _bidController.text.trim().isEmpty) {
      _ensureBidForNode(_selectedNodeBid!);
    }

    final bid = _bidController.text.trim();
    if (bid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('BID 不能为空')));
      return;
    }

    final nextData = Map<String, dynamic>.from(widget.initialData.data);
    nextData['bid'] = bid;
    nextData['tag'] = _tags;
    nextData['link_tag'] = _linkTags;
    nextData['link'] = _links;
    nextData['permission_level'] = _permissionLevel;
    if (nextData.containsKey('link_tags')) {
      nextData['link_tags'] = _linkTags;
    }

    if (_selectedNodeBid != null) {
      nextData['node_bid'] = _selectedNodeBid;
      if (_selectedNodeName != null) {
        nextData['node_name'] = _selectedNodeName;
      }
      if (_selectedNodeAddress != null) {
        nextData['node_connection_address'] = _selectedNodeAddress;
      }
    } else {
      nextData.remove('node_bid');
      nextData.remove('node_name');
      nextData.remove('node_connection_address');
    }

    Navigator.of(context).pop(BlockModel(data: nextData));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.allowNodeSelection) ...[
                      _buildNodeSelectorSection(),
                      const SizedBox(height: 32),
                    ],
                    _buildTagSection(),
                    const SizedBox(height: 32),
                    _buildLinkTagSection(),
                    const SizedBox(height: 32),
                    _buildPermissionSection(),
                    const SizedBox(height: 32),
                    _buildLinkSection(),
                    const SizedBox(height: 32),
                    _buildBidSection(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessingLink ? null : _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('完成'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeSelectorSection() {
    final hasSelection = _hasNodeSelection;
    final displayName = hasSelection
        ? (_selectedNodeName?.isNotEmpty == true ? _selectedNodeName! : '未命名节点')
        : '未选择节点';
    final subtitle = hasSelection ? formatBid(_selectedNodeBid!) : '请选择一个节点';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BlockSectionHeader(title: '节点'),
        const SizedBox(height: 14),
        _NodeSelectorCard(
          title: displayName,
          subtitle: subtitle,
          hasSelection: hasSelection,
          onTap: _handlePickNode,
        ),
        const SizedBox(height: 10),
        Text(
          '节点决定 BID 的前缀，同时也是写入指令的接收者。',
          style: TextStyle(
            color: Colors.white.withOpacity(0.52),
            fontSize: 12,
            height: 1.3,
          ),
        ),
        if (!hasSelection)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '请选择节点后才能创建 Block。',
              style: TextStyle(
                color: Color(0xFFFFB74D),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BlockSectionHeader(title: '标签'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in _tags)
              _TagChip(
                label: tag,
                onRemove: () => _handleRemoveTag(tag),
              ),
            _TagAddButton(
              onTap: () => _handleAddTagDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkTagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BlockSectionHeader(title: '链接标签'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in _linkTags)
              _TagChip(
                label: tag,
                onRemove: () => _handleRemoveLinkTag(tag),
              ),
            _LinkTagAddButton(
              onTap: () => _handleAddLinkTagDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPermissionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BlockSectionHeader(title: '权限'),
        const SizedBox(height: 16),
        BlockPermissionCard(
          permissionLevel: _permissionLevel.toString(),
          color: _permissionColor(_permissionLevel),
          description: _describePermission(_permissionLevel),
        ),
        const SizedBox(height: 16),
        _PermissionSelector(
          currentLevel: _permissionLevel,
          onChanged: (value) => setState(() => _permissionLevel = value),
        ),
      ],
    );
  }

  Widget _buildLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BlockSectionHeader(title: '链接'),
        const SizedBox(height: 16),
        _AddLinkCard(
          isProcessing: _isProcessingLink,
          onPressed: _handleAddLink,
        ),
        if (_links.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _links
                .map(
                  (bid) => _LinkChip(
                    bid: bid,
                    onRemove: () => _handleRemoveLink(bid),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildBidSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BlockSectionHeader(title: 'BID'),
        const SizedBox(height: 12),
        TextField(
          controller: _bidController,
          readOnly: true,
          enableInteractiveSelection: false,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 0.6,
          ),
          decoration: InputDecoration(
            hintText: 'BID 将自动生成',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1D1D20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.28)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '预览：${formatBid(_bidController.text)}',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Color _permissionColor(int level) {
    switch (level) {
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

  String _describePermission(int level) {
    switch (level) {
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
}

class _BasicEditorHeader extends StatelessWidget {
  const _BasicEditorHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            splashRadius: 20,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white54,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagAddButton extends StatelessWidget {
  const _TagAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          shape: _DashedRectBorder(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '+ 添加标签',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _LinkTagAddButton extends StatelessWidget {
  const _LinkTagAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          shape: _DashedRectBorder(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '+ 添加链接标签',
          style: TextStyle(
            color: Colors.white54,
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

class _PermissionSelector extends StatelessWidget {
  const _PermissionSelector({
    required this.currentLevel,
    required this.onChanged,
  });

  final int currentLevel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const levels = [0, 1, 2, 3, 4];
    return Wrap(
      spacing: 10,
      children: levels
          .map(
            (level) => ChoiceChip(
              label: Text('等级 $level'),
              selected: currentLevel == level,
              selectedColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.05),
              labelStyle: TextStyle(
                color: currentLevel == level ? Colors.black : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              onSelected: (_) => onChanged(level),
            ),
          )
          .toList(),
    );
  }
}

class _AddLinkCard extends StatelessWidget {
  const _AddLinkCard({required this.isProcessing, required this.onPressed});

  final bool isProcessing;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.white.withOpacity(0.85);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isProcessing ? null : onPressed,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 0.9,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add_link, color: themeColor, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '添加链接',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (isProcessing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right, color: themeColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.bid, required this.onRemove});

  final String bid;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_outlined, color: Colors.white60, size: 14),
          const SizedBox(width: 8),
          Text(
            formatBid(bid),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white54,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeSelectorCard extends StatelessWidget {
  const _NodeSelectorCard({
    required this.title,
    required this.subtitle,
    required this.hasSelection,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool hasSelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlightColor = const Color(0xFFFFB74D);
    final borderColor =
        hasSelection ? Colors.white.withOpacity(0.12) : highlightColor.withOpacity(0.8);
    final backgroundColor =
        hasSelection ? Colors.white.withOpacity(0.04) : highlightColor.withOpacity(0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            color: backgroundColor,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.08),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.hub_outlined,
                  color: hasSelection ? Colors.white : highlightColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: hasSelection ? Colors.white : highlightColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: hasSelection ? Colors.white60 : highlightColor.withOpacity(0.9),
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right,
                color: hasSelection ? Colors.white54 : highlightColor,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodePickerSheet extends StatelessWidget {
  const _NodePickerSheet({
    required this.nodes,
    this.initialAddress,
    this.initialNodeBid,
  });

  final List<ConnectionModel> nodes;
  final String? initialAddress;
  final String? initialNodeBid;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111112),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '选择节点',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: nodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final node = nodes[index];
                    final nodeBid = node.nodeData?['sender'] as String? ?? '';
                    final isSelected = (initialAddress != null && node.address == initialAddress) ||
                        (initialAddress == null &&
                            initialNodeBid != null &&
                            nodeBid == initialNodeBid);
                    return _NodePickerTile(
                      connection: node,
                      bid: nodeBid,
                      isSelected: isSelected,
                      onTap: () => Navigator.of(context).pop(node),
                    );
                  },
                ),
              ),
              SizedBox(height: bottomPadding > 0 ? bottomPadding : 16),
            ],
          ),
        );
      },
    );
  }
}

class _NodePickerTile extends StatelessWidget {
  const _NodePickerTile({
    required this.connection,
    required this.bid,
    required this.isSelected,
    required this.onTap,
  });

  final ConnectionModel connection;
  final String bid;
  final bool isSelected;
  final VoidCallback onTap;

  Color get _statusColor {
    switch (connection.status) {
      case ConnectionStatus.connected:
        return const Color(0xFF4CAF50);
      case ConnectionStatus.connecting:
        return const Color(0xFF26C6DA);
      case ConnectionStatus.offline:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.12),
            width: isSelected ? 1.2 : 1,
          ),
          color: isSelected ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.03),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          connection.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.white70, size: 18),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    connection.address,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (bid.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'BID: ${formatBid(bid)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
