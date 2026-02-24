import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:block_app/core/network/api/block_api.dart';

import '../../../core/models/block_model.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/storage/cache/block_cache.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../features/link/pages/link_page.dart';
import '../../common/block_detail_page.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../../../utils/file_category.dart';
import '../../file/models/file_card_data.dart';
import '../../../state/block_detail_listener_mixin.dart';


class RecordDetailPage extends StatefulWidget {
  const RecordDetailPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> with BlockDetailListenerMixin {
  ImageProvider? _coverImage;
  bool _coverLoading = false;
  bool _coverError = false;
  String? _currentCoverBid;
  late BlockModel _currentBlock;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _currentBlock = updatedBlock;
      // Reload cover if cover_bid changed
      final newCoverBid = _resolveCoverBid(updatedBlock);
      if (newCoverBid != null && newCoverBid != _currentCoverBid) {
        _loadCover(newCoverBid, force: true);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _currentBlock = widget.block;
    startBlockProviderListener();
    final coverBid = _resolveCoverBid(_currentBlock);
    if (coverBid != null && coverBid.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCover(coverBid));
    }
  }

  @override
  void dispose() {
    stopBlockProviderListener();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RecordDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldBid = _resolveCoverBid(BlockModel(data: oldWidget.block.data));
    final newBid = _resolveCoverBid(_currentBlock);
    if (oldBid != newBid) {
      if (newBid != null && newBid.isNotEmpty) {
        _loadCover(newBid, force: true);
      } else {
        setState(() {
          _coverImage = null;
          _coverLoading = false;
          _coverError = false;
          _currentCoverBid = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(toolbarHeight: 0), body: _buildBody());
  }

  Widget _buildBody() {
    final block = _currentBlock;
    final title = block.maybeString('name') ?? '未命名档案';
    final intro = block.maybeString('intro') ?? '';
    final address = block.maybeString('address');
    final timeText = _resolveTime(block);
    final bid = block.maybeString('bid')?.trim();
    final coverBid = _resolveCoverBid(block);
    final tags = _resolveTags(block);
    final precisionLabels = _resolvePrecisionLabels(block);

    return Container(
      color: Colors.black,
      child: RefreshIndicator(
        onRefresh: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BlockDetailPage(block: block)),
          );
        },
        backgroundColor: Colors.black,
        color: Colors.white,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 60),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(),
                  const SizedBox(height: 32),
                  if (_shouldShowCover(coverBid)) ...[
                    _buildCoverSection(),
                    const SizedBox(height: 32),
                  ],
                  _buildTitle(title),
                  if (timeText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTime(timeText, precisionLabels),
                  ],
                  if (address != null && address.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _buildAddress(address.trim()),
                  ],
                  if (intro.trim().isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildIntro(intro.trim()),
                  ],
                  if (precisionLabels.isNotEmpty && intro.trim().isEmpty)
                    const SizedBox(height: 8),
                  if (bid != null && bid.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildExternalLinkButton(bid),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildTags(tags),
                  ],
                  if (bid != null && bid.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildBid(bid),
                  ],
                  const SizedBox(height: 120),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: const Text(
            '档案',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.1,
      ),
    );
  }

  Widget _buildAddress(String address) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.place_outlined,
            size: 15,
            color: Colors.white70,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTime(String timeText, List<String> precisionLabels) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.schedule_outlined, size: 16, color: Colors.white54),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeText,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              if (precisionLabels.isNotEmpty) ...[
                const SizedBox(height: 10),
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
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.16),
                              width: 0.7,
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntro(String intro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          intro,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.6,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTags(List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标签',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map(
                (tag) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 0.8,
                    ),
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPrecision(List<String> labels) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '时间备注',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: labels
              .map(
                (label) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.16),
                      width: 0.8,
                    ),
                    color: Colors.white.withOpacity(0.08),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildBid(String bid) {
    return Container(
      margin: const EdgeInsets.only(top: 36, bottom: 36),
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

  Widget _buildExternalLinkButton(String bid) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LinkPage(bid: bid, initialIndex: 1),
            ),
          );
        },
        icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white70),
        label: const Text(
          '外链',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24, width: 0.8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  List<String> _resolveTags(BlockModel block) {
    final list = block.list<dynamic>('tag');
    return list
        .whereType<String>()
        .where((tag) => tag.trim().isNotEmpty)
        .map((tag) => tag.trim())
        .toList();
  }

  List<String> _resolvePrecisionLabels(BlockModel block) {
    final labels = <String>[];
    if (block.maybeBool('precise_date') ?? false) {
      labels.add('精准日期');
    }
    if (block.maybeBool('precise_time') ?? false) {
      labels.add('精准时间');
    }
    if (block.maybeBool('time_range') ?? false) {
      labels.add('范围时间');
    }
    return labels;
  }

  String _resolveTime(BlockModel block) {
    final addTime = block.maybeString('add_time')?.trim();
    final preciseTime = block.maybeBool('precise_time') ?? false;
    if (addTime != null && addTime.isNotEmpty) {
      final parsed = DateTime.tryParse(addTime);
      if (parsed != null) {
        final date = formatDate(parsed);
        if (preciseTime) {
          final hour = parsed.hour.toString().padLeft(2, '0');
          final minute = parsed.minute.toString().padLeft(2, '0');
          final second = parsed.second.toString().padLeft(2, '0');
          return '$date $hour:$minute:$second';
        }
        return date;
      }
      return addTime;
    }
    final createdAt = block.getDateTime('createdAt');
    if (createdAt != null) {
      return formatDate(createdAt);
    }
    final updatedAt = block.getDateTime('updatedAt');
    if (updatedAt != null) {
      return formatDate(updatedAt);
    }
    return '';
  }

  Widget _buildCoverSection() {
    if (_coverImage == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1F1F27), Color(0xFF14141B)],
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
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.45),
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
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white70,
                    ),
                  ),
                )
              else
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.36),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 0.7,
                      ),
                    ),
                    child: const Text(
                      '档案封面',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 0.6,
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
        variant: ImageVariant.original,
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

  String? _resolveCoverBid(BlockModel block) {
    return block.maybeString('cover_bid') ??
        block.maybeString('coverBid') ??
        block.maybeString('cover');
  }

  bool _shouldShowCover(String? coverBid) {
    if (_coverLoading) {
      return true;
    }
    if (_coverImage != null) {
      return true;
    }
    if (coverBid != null && coverBid.isNotEmpty) {
      return true;
    }
    return false;
  }
}
