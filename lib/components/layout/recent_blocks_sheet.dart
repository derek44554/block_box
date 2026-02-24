import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../blocks/file/models/file_card_data.dart';
import '../../blocks/file/widgets/image_file_card.dart';
import '../../blocks/gps/widgets/gps_simple.dart';
import '../../blocks/service/widgets/service_card.dart';
import '../../blocks/set/widgets/collection_card.dart';
import '../../blocks/user/widgets/user_card.dart';
import '../../core/models/block_model.dart';
import 'package:block_app/core/network/api/block_api.dart';
import '../../state/connection_provider.dart';
import '../../core/utils/formatters/bid_formatter.dart';
import '../../utils/recent_blocks_manager.dart';
import '../../blocks/document/widgets/document_card.dart';
import '../../blocks/article/widgets/article_card.dart';
import '../../utils/file_category.dart';

/// 最近创建的Block选择面板。
///
/// 以底部弹出的形式展示最近创建的Block，方便快速选择一个 BID。
/// 选择Block后会自动关闭并返回对应的 BID。
class RecentBlocksSheet extends StatefulWidget {
  const RecentBlocksSheet({super.key});

  static const double _cardRadius = 16;
  static const TextStyle _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RecentBlocksSheet(),
    );
  }

  @override
  State<RecentBlocksSheet> createState() => _RecentBlocksSheetState();
}

class _RecentBlocksSheetState extends State<RecentBlocksSheet> {
  List<BlockModel> _recentBlocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentBlocks();
  }

  Future<void> _loadRecentBlocks() async {
    // 首先获取本地保存的最近BID列表
    final recentBids = await RecentBlocksManager.getRecentBids();

    if (recentBids.isEmpty) {
      if (mounted) {
        setState(() {
          _recentBlocks = [];
          _isLoading = false;
        });
      }
      return;
    }

    final provider = context.read<ConnectionProvider>();
    final api = BlockApi(connectionProvider: provider);

    // 使用 /multiple 接口获取多个Block
    final response = await api.getMultipleBlocks(bids: recentBids);

    // 从 data 字段中获取 blocks
    final data = response['data'];
    final blocks = data?['blocks'];

    if (blocks is List) {
      // 创建BID到Block的映射
      final Map<String, BlockModel> blockMap = {};
      for (final item in blocks.whereType<Map<String, dynamic>>()) {
        final block = BlockModel(data: item);
        final bid = block.maybeString('bid');
        if (bid != null && bid.isNotEmpty) {
          blockMap[bid] = block;
        }
      }

      // 按照BID列表的顺序重新排列Block
      final orderedBlocks = <BlockModel>[];
      for (final bid in recentBids) {
        final block = blockMap[bid];
        if (block != null) {
          orderedBlocks.add(block);
        }
      }

      if (mounted) {
        setState(() {
          _recentBlocks = orderedBlocks;
          _isLoading = false;
        });
      }
    } else {
      throw Exception(
        'Invalid response format: expected List but got ${blocks.runtimeType}. Response: $response',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: safePadding),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        expand: false,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF111112),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '最近创建',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '选择一个Block后，即可快速填充到链接列表。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildContent(controller)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(ScrollController controller) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
      );
    }

    if (_recentBlocks.isEmpty) {
      return const _EmptyView();
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: _recentBlocks.length,
      itemBuilder: (context, index) {
        final block = _recentBlocks[index];
        return _buildBlockCard(block);
      },
    );
  }

  Widget _buildBlockCard(BlockModel block) {
    final bid = block.maybeString('bid') ?? '';
    final model = block.maybeString('model') ?? '';

    // 创建返回BID的回调
    final onTap = () => Navigator.of(context).pop(bid);

    switch (model) {
      case '93b133932057a254cc15d0f09c91ca98': // Document
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DocumentCard(block: block, onTap: onTap),
        );
      case 'c4238dd0d3d95db7b473adb449f6d282': // File
        final fileData = FileCardData.fromBlock(block);
        if (resolveFileCategory(fileData.extension).isImage) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ImageFileCard(
              block: block,
              cardData: fileData,
              onTap: onTap,
            ),
          );
        } else {
          // 对于非图片文件，使用简单的卡片
          return _buildSimpleCard(block, onTap);
        }
      case '1635e536a5a331a283f9da56b7b51774': // Set
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CollectionCard(block: block, onTap: onTap),
        );
      case '81b0bc8db4f678300d199f5b34729282': // Service
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ServiceCard(block: block, onTap: onTap),
        );
      case '71b6eb41f026842b3df6b126dfe11c29': // User
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: UserCard(block: block, onTap: onTap),
        );
      case '52da1e115d0a764b43c90f6b43284aa9': // Article
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ArticleCard(block: block, onTap: onTap),
        );
      case '5b877cf0259538958f4ce032a1de7ae7': // GPS
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GpsSimple(block: block, onTap: onTap),
        );
      default:
        return _buildSimpleCard(block, onTap);
    }
  }

  Widget _buildSimpleCard(BlockModel block, VoidCallback onTap) {
    final bid = block.maybeString('bid') ?? '';
    final model = block.maybeString('model') ?? '';
    final title = block.maybeString('name') ?? '未命名';
    final addTime =
        block.getDateTime('add_time') ?? block.getDateTime('createdAt');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181A),
        borderRadius: BorderRadius.circular(RecentBlocksSheet._cardRadius),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.6),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RecentBlocksSheet._cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildIcon(model),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: RecentBlocksSheet._titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bid,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (addTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatDate(addTime),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String model) {
    IconData icon;
    Color color;

    switch (model) {
      case '93b133932057a254cc15d0f09c91ca98': // Document
        icon = Icons.description_outlined;
        color = Colors.blue;
        break;
      case 'c4238dd0d3d95db7b473adb449f6d282': // File
        icon = Icons.insert_drive_file_outlined;
        color = Colors.green;
        break;
      case '1635e536a5a331a283f9da56b7b51774': // Set
        icon = Icons.collections_bookmark_outlined;
        color = Colors.purple;
        break;
      case '81b0bc8db4f678300d199f5b34729282': // Service
        icon = Icons.public_outlined;
        color = Colors.orange;
        break;
      case '52da1e115d0a764b43c90f6b43284aa9': // Article
        icon = Icons.article_outlined;
        color = Colors.teal;
        break;
      default:
        icon = Icons.circle_outlined;
        color = Colors.grey;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.history_outlined, color: Colors.white24, size: 42),
            SizedBox(height: 16),
            Text(
              '暂无最近创建的Block',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              '创建一些Block后，它们会出现在这里。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
