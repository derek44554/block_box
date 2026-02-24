import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:block_app/core/network/api/block_api.dart';

import '../../../core/models/block_model.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/storage/cache/block_cache.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/widgets/common/tag_widget.dart';
import '../../common/block_detail_page.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../../../utils/file_category.dart';
import '../../file/models/file_card_data.dart';
import '../../../state/block_detail_listener_mixin.dart';


/// 用户块详情页，展示身份信息、头像与联系方式等内容。
class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> with BlockDetailListenerMixin {
  ImageProvider? _avatarProvider;
  bool _avatarLoading = false;
  bool _avatarError = false;
  late BlockModel _currentBlock;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _currentBlock = updatedBlock;
      // Reload avatar if avatar_bid changed
      final newAvatarBid = updatedBlock.maybeString('avatar_bid');
      if (newAvatarBid != null && newAvatarBid.trim().isNotEmpty) {
        _loadAvatar(newAvatarBid);
      }
    });
  }

  static const Map<String, String> _typeLabels = {
    'humanity': '人类',
    'animal': '动物',
    'ai': '人工智能',
    'company': '公司',
    'organize': '组织',
  };

  static const Map<String, String> _genderLabels = {
    'male': '男',
    'female': '女',
    'other': '其他',
    'unknown': '未知',
  };

  @override
  void initState() {
    super.initState();
    _currentBlock = widget.block;
    startBlockProviderListener();
    final avatarBid = _currentBlock.maybeString('avatar_bid');
    if (avatarBid != null && avatarBid.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadAvatar(avatarBid),
      );
    }
  }

  @override
  void dispose() {
    stopBlockProviderListener();
    super.dispose();
  }

  Future<void> _loadAvatar(String bid) async {
    final trimmed = bid.trim();
    if (trimmed.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _avatarLoading = true;
      _avatarError = false;
    });

    try {
      final connection = context.read<ConnectionProvider>();
      final endpoint = connection.ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        throw Exception('未配置 IPFS 节点');
      }

      // 1. 先尝试从缓存获取 Block 元数据
      BlockModel? avatarBlock = await BlockCache.instance.get(trimmed);
      
      // 2. 如果缓存未命中，从 API 获取并缓存
      if (avatarBlock == null) {
        final api = BlockApi(connectionProvider: connection);
        final response = await api.getBlock(bid: trimmed);
        final data = response['data'];
        if (data is! Map<String, dynamic> || data.isEmpty) {
          throw Exception('头像对应的 Block 数据为空');
        }

        avatarBlock = BlockModel(data: data);
        
        // 保存到缓存
        await BlockCache.instance.put(trimmed, avatarBlock);
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
        variant: ImageVariant.medium,
      );

      if (!mounted) return;
      setState(() {
        _avatarProvider = result.provider;
        _avatarLoading = false;
        _avatarError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _avatarLoading = false;
        _avatarError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _currentBlock.maybeString('name') ?? '未命名用户';
    final survive = _currentBlock.maybeBool('survive') ?? true;
    final type = _currentBlock.maybeString('type');
    final gender = _currentBlock.maybeString('gender');
    final origin = _currentBlock.maybeString('origin');
    final intro = _currentBlock.maybeString('intro');
    final introData = _currentBlock.maybeString('intro_data');
    final tags = _currentBlock.list<String>('tag');
    final contactData = _currentBlock.maybeString('contact_data');
    final bid = _currentBlock.maybeString('bid');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlockDetailPage(block: _currentBlock),
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
                    _buildTitle(name),
                    const SizedBox(height: 26),
                    _buildAvatarSection(),
                    _buildName(name),
                    if (survive || (type != null && type.isNotEmpty)) ...[
                      const SizedBox(height: 24),
                      _buildInfoChips(
                        survive: survive,
                        type: type,
                        gender: gender,
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      TagWidget(tags: tags),
                    ],
                    if (origin != null && origin.trim().isNotEmpty) ...[
                      const SizedBox(height: 32),
                      _InfoBlock(title: '起源', content: _formatOrigin(origin)),
                    ],
                    if (contactData != null &&
                        contactData.trim().isNotEmpty) ...[
                      const SizedBox(height: 32),
                      _InfoBlock(title: '联系方式', content: contactData.trim()),
                    ],
                    if (intro != null && intro.trim().isNotEmpty) ...[
                      const SizedBox(height: 32),
                      _InfoBlock(
                        title: '介绍',
                        content: intro.trim(),
                        maxLines: 6,
                      ),
                    ],
                    if (introData != null && introData.trim().isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _buildIntroData(introData.trim()),
                    ],
                    if (bid != null) ...[
                      const SizedBox(height: 40),
                      _buildBid(bid),
                    ],
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

  Widget _buildTitle(String name) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 0.8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          '用户',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 1.8,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    const double size = 160;
    const double corner = 12;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(corner),
          gradient: const LinearGradient(
            colors: [Color(0xFF1F1F24), Color(0xFF141418)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(corner - 4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_avatarProvider != null)
                Image(image: _avatarProvider!, fit: BoxFit.cover)
              else if (_avatarLoading)
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                )
              else
                Center(
                  child: Icon(
                    _avatarError
                        ? Icons.broken_image_outlined
                        : Icons.person_outline,
                    color: Colors.white24,
                    size: 48,
                  ),
                ),
              if (_avatarProvider == null)
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '头像',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildName(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 22),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChips({
    required bool survive,
    String? type,
    String? gender,
  }) {
    final chips = <Widget>[
      _InfoChip(
        label: survive ? '存活' : '归档',
        gradient: LinearGradient(
          colors: survive
              ? const [Color(0xFF191C1A), Color(0xFF111411)]
              : const [Color(0xFF211819), Color(0xFF140E0E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ];

    if (type != null && type.trim().isNotEmpty) {
      chips.add(
        _InfoChip(
          label: _typeLabels[type] ?? type,
          gradient: const LinearGradient(
            colors: [Color(0xFF1B1B1F), Color(0xFF121214)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }

    if (gender != null && gender.trim().isNotEmpty) {
      final normalized = gender.trim();
      chips.add(
        _InfoChip(
          label: _genderLabels[normalized] ?? normalized,
          gradient: const LinearGradient(
            colors: [Color(0xFF1C1C20), Color(0xFF151518)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }

    return Wrap(spacing: 10, runSpacing: 8, children: chips);
  }

  Widget _buildIntroData(String introData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '描述性信息数据',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 0.6,
            ),
          ),
          child: SelectableText(
            introData,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBid(String bid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BID',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 1,
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
          ),
        ),
      ],
    );
  }

  String _formatOrigin(String origin) {
    final trimmed = origin.trim();
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return formatDate(parsed, fallback: trimmed);
    }
    return trimmed;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.gradient});

  final String label;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.content, this.maxLines});

  final String title;
  final String content;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.6,
            letterSpacing: 0.4,
          ),
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null,
        ),
      ],
    );
  }
}
