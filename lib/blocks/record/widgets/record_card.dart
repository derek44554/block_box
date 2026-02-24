import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:block_app/core/network/api/block_api.dart';

import '../../../core/models/block_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/storage/cache/block_cache.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../../../utils/file_category.dart';
import '../../../widgets/border/document_border.dart';
import '../../file/models/file_card_data.dart';


class RecordCard extends StatefulWidget {
  const RecordCard({super.key, required this.block, this.onTap});

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  State<RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<RecordCard> {
  ImageProvider? _coverImage;
  bool _coverLoading = false;
  bool _coverError = false;
  String? _currentCoverBid;

  BlockModel get _block => widget.block;

  @override
  void initState() {
    super.initState();
    final coverBid = _resolveCoverBid(_block);
    if (coverBid != null && coverBid.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCover(coverBid));
    }
  }

  @override
  void didUpdateWidget(covariant RecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldBid = oldWidget.block.maybeString('cover_bid')?.trim();
    final newBid = _resolveCoverBid(_block)?.trim();
    if (oldBid != newBid) {
      if (newBid != null && newBid.isNotEmpty) {
        _loadCover(newBid, force: true);
      } else {
        setState(() {
          _coverImage = null;
          _coverError = false;
          _coverLoading = false;
          _currentCoverBid = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _block.maybeString('name')?.trim();
    final intro = _block.maybeString('intro')?.trim();
    final address = _block.maybeString('address')?.trim();
    final preciseTime = _block.maybeBool('precise_time') ?? false;
    final addTime = _formatAddTime(
      _block.maybeString('add_time'),
      includeTime: preciseTime,
    );
    final formattedBid = formatBid(_block.maybeString('bid') ?? '');
    final precisionLabels = _resolvePrecisionLabels();
    final coverBid = _resolveCoverBid(_block);
    final hasCoverSlot =
        (coverBid != null && coverBid.isNotEmpty) ||
        _coverImage != null ||
        _coverLoading;

    return GestureDetector(
      onTap:
          widget.onTap ?? () => AppRouter.openBlockDetailPage(context, _block),
      child: DocumentBorder(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, addTime),
              if (hasCoverSlot) ...[
                const SizedBox(height: 16),
                _buildCoverSection(),
              ],
              const SizedBox(height: 14),
              Text(
                title == null || title.isEmpty ? '未命名档案' : title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (address != null && address.isNotEmpty)
                _buildIconRow(icon: Icons.place_outlined, text: address),
              if (address != null && address.isNotEmpty)
                const SizedBox(height: 10),
              Text(
                (intro != null && intro.isNotEmpty) ? intro : '暂无介绍',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.86),
                  fontSize: 13,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (precisionLabels.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: precisionLabels
                      .map(
                        (label) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 0.6,
                      ),
                    ),
                    child: const Text(
                      '档案',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formattedBid,
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF202027), Color(0xFF15151C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_coverImage != null)
                Image(image: _coverImage!, fit: BoxFit.cover),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.35),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              if (_coverLoading)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                )
              else if (_coverImage == null)
                Center(
                  child: Icon(
                    _coverError
                        ? Icons.broken_image_outlined
                        : Icons.image_outlined,
                    color: Colors.white38,
                    size: 32,
                  ),
                ),
              if (_coverImage != null)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.16),
                        width: 0.6,
                      ),
                    ),
                    child: const Text(
                      '封面',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 0.5,
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

  Widget _buildHeader(BuildContext context, String addTime) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.folder_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '档案记录',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              if (addTime.isNotEmpty)
                Text(
                  addTime,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadCover(String bid, {bool force = false}) async {
    final trimmed = bid.trim();
    if (trimmed.isEmpty || !mounted) {
      return;
    }
    if (!force && _currentCoverBid == trimmed && _coverImage != null) {
      return;
    }

    setState(() {
      _coverLoading = true;
      _coverError = false;
      _currentCoverBid = trimmed;
    });

    try {
      final connection = context.read<ConnectionProvider>();
      final endpoint = connection.ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        throw Exception('未配置 IPFS 节点');
      }

      // 1. 先尝试从缓存获取 Block 元数据
      BlockModel? coverBlock = await BlockCache.instance.get(trimmed);
      
      // 2. 如果缓存未命中，从 API 获取并缓存
      if (coverBlock == null) {
        final api = BlockApi(connectionProvider: connection);
        final response = await api.getBlock(bid: trimmed);
        final data = response['data'];
        if (data is! Map<String, dynamic> || data.isEmpty) {
          throw Exception('封面 Block 数据为空');
        }

        coverBlock = BlockModel(data: Map<String, dynamic>.from(data));
        
        // 保存到缓存
        await BlockCache.instance.put(trimmed, coverBlock);
      }

      final fileData = FileCardData.fromBlock(coverBlock);
      final category = resolveFileCategory(fileData.extension);
      if (!category.isImage) {
        throw Exception('封面 Block 不是图片类型');
      }
      final cid = fileData.cid;
      if (cid == null || cid.isEmpty) {
        throw Exception('封面缺少 CID');
      }

      final result = await BlockImageLoader.instance.loadVariant(
        data: fileData,
        endpoint: endpoint,
        variant: ImageVariant.medium,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _coverImage = result.provider;
        _coverLoading = false;
        _coverError = false;
        _currentCoverBid = trimmed;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _coverImage = null;
        _coverLoading = false;
        _coverError = true;
        _currentCoverBid = trimmed;
      });
    }
  }

  String _formatAddTime(String? time, {required bool includeTime}) {
    final trimmed = time?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final date = formatDate(parsed);
      if (includeTime) {
        final hour = parsed.hour.toString().padLeft(2, '0');
        final minute = parsed.minute.toString().padLeft(2, '0');
        final second = parsed.second.toString().padLeft(2, '0');
        return '$date $hour:$minute:$second';
      }
      return date;
    }
    return trimmed;
  }

  List<String> _resolvePrecisionLabels() {
    final labels = <String>[];
    if (_block.maybeBool('precise_date') ?? false) {
      labels.add('精准日期');
    }
    if (_block.maybeBool('precise_time') ?? false) {
      labels.add('精准时间');
    }
    if (_block.maybeBool('time_range') ?? false) {
      labels.add('范围时间');
    }
    return labels;
  }

  String? _resolveCoverBid(BlockModel block) {
    return block.maybeString('cover_bid') ??
        block.maybeString('coverBid') ??
        block.maybeString('cover');
  }
}
