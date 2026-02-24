import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:block_app/core/network/api/block_api.dart';

import '../../../core/models/block_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/storage/cache/block_cache.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/widgets/common/tag_widget.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../../../utils/file_category.dart';
import '../../../widgets/border/document_border.dart';
import '../../file/models/file_card_data.dart';


/// 用户块卡片，展示基本信息与头像预览。
class UserCard extends StatefulWidget {
  const UserCard({super.key, required this.block, this.onTap});

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
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

  ImageProvider? _avatarProvider;
  bool _avatarLoading = false;
  bool _avatarError = false;
  String? _currentAvatarBid;

  @override
  void initState() {
    super.initState();
    final avatarBid = widget.block.maybeString('avatar_bid');
    if (avatarBid != null && avatarBid.trim().isNotEmpty) {
      _currentAvatarBid = avatarBid.trim();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadAvatar(avatarBid),
      );
    }
  }

  @override
  void didUpdateWidget(covariant UserCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldBid = oldWidget.block.maybeString('avatar_bid')?.trim();
    final newBid = widget.block.maybeString('avatar_bid')?.trim();
    if (oldBid == newBid) {
      return;
    }
    if (newBid == null || newBid.isEmpty) {
      setState(() {
        _currentAvatarBid = null;
        _avatarProvider = null;
        _avatarLoading = false;
        _avatarError = false;
      });
      return;
    }
    _currentAvatarBid = newBid;
    _avatarProvider = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAvatar(newBid));
  }

  Future<void> _loadAvatar(String bid) async {
    final trimmed = bid.trim();
    if (trimmed.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _avatarLoading = true;
      _avatarError = false;
      _avatarProvider = null;
      _currentAvatarBid = trimmed;
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
        variant: ImageVariant.small,
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
    final name = widget.block.maybeString('name') ?? '未命名用户';
    final tags = widget.block.list<String>('tag');
    final survive = widget.block.maybeBool('survive') ?? true;
    final type = widget.block.maybeString('type');
    final gender = widget.block.maybeString('gender');
    final originText = widget.block.maybeString('origin');
    final avatarBid = widget.block.maybeString('avatar_bid');
    final intro = widget.block.maybeString('intro');
    final bid = widget.block.maybeString('bid');

    return GestureDetector(
      onTap:
          widget.onTap ??
          () => AppRouter.openBlockDetailPage(context, widget.block),
      child: DocumentBorder(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 16,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                                letterSpacing: 0.6,
                                height: 1.28,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        _buildInfoChipsRow(
                          survive: survive,
                          type: type,
                          gender: gender,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                TagWidget(tags: tags),
              ],
              if (originText != null && originText.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                _InfoTile(label: '起源', value: _formatOrigin(originText)),
              ],
              if (avatarBid != null && avatarBid.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoTile(label: '头像 BID', value: formatBid(avatarBid)),
              ],
              if (intro != null && intro.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                _InfoTile(label: '介绍', value: intro.trim(), maxLines: 3),
              ],
              const SizedBox(height: 20),
              if (bid != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    formatBid(bid),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      letterSpacing: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    const double size = 78;
    const double corner = 8;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(corner),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F24), Color(0xFF141418)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(corner - 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_avatarProvider != null)
              Image(image: _avatarProvider!, fit: BoxFit.cover)
            else if (_avatarLoading)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
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
                  color: Colors.white38,
                  size: 32,
                ),
              ),
            if (_avatarProvider == null)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '头像',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool survive) {
    final colors = survive
        ? [const Color(0xFF1C1C1F), const Color(0xFF131315)]
        : [const Color(0xFF262022), const Color(0xFF181214)];
    return _InfoChip(
      label: survive ? '存活' : '归档',
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final label = _typeLabels[type] ?? '未知类型';
    return _InfoChip(
      label: label,
      gradient: LinearGradient(
        colors: const [Color(0xFF1B1B1F), Color(0xFF121214)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  Widget _buildInfoChipsRow({
    required bool survive,
    String? type,
    String? gender,
  }) {
    final chips = <Widget>[_buildStatusChip(survive)];

    if (type != null && type.trim().isNotEmpty) {
      chips.add(_buildTypeChip(type));
    }

    if (gender != null && gender.trim().isNotEmpty) {
      final normalized = gender.trim();
      final label = _genderLabels[normalized] ?? normalized;
      chips.add(
        _InfoChip(
          label: label,
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

  String _formatOrigin(String origin) {
    final parsed = DateTime.tryParse(origin.trim());
    if (parsed != null) {
      return formatDate(parsed, fallback: origin.trim());
    }
    return origin.trim();
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11.5,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
            letterSpacing: 0.4,
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
