import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/block_model.dart';
import 'package:block_app/core/network/api/block_api.dart';

import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/widgets/common/tag_widget.dart';
import '../../../features/link/pages/link_page.dart';
import '../../common/block_detail_page.dart';
import '../../../state/connection_provider.dart';
import '../../../state/block_detail_listener_mixin.dart';


class SetDetailPage extends StatefulWidget {
  const SetDetailPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<SetDetailPage> createState() => _SetDetailPageState();
}

class _SetDetailPageState extends State<SetDetailPage> with BlockDetailListenerMixin {
  int? _linkCount;
  bool _isLoadingLinkCount = false;
  late BlockModel _currentBlock;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _currentBlock = updatedBlock;
    });
  }

  @override
  void initState() {
    super.initState();
    _currentBlock = widget.block;
    startBlockProviderListener();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLinkCounts());
  }

  @override
  void dispose() {
    stopBlockProviderListener();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      body: _buildSetDetailPage(),
    );
  }

  Widget _buildSetDetailPage() {
    final title = _currentBlock.maybeString('name');
    final bid = _currentBlock.maybeString('bid');
    final desc = _currentBlock.maybeString('intro');
    final tags = _currentBlock.getList<String>('tag');

    return Container(
      color: Colors.black,
      child: RefreshIndicator(
        onRefresh: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlockDetailPage(block: _currentBlock),
            ),
          );
          if (mounted) {
            await _loadLinkCounts();
          }
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
                  if (title != null) _buildTitle(title),
                  if (desc != null) _buildDescription(desc),
                  if (tags.isNotEmpty) _buildTags(tags),
                  if (bid != null) _buildLinkSection(bid),
                  if (bid != null) _buildBid(bid),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '集合',
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

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.1,
      ),
    );
  }

  Widget _buildDescription(String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        desc,
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

  Widget _buildLinkSection(String bid) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '链接',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _LinkButton(
                label: '链接',
                icon: Icons.link,
                count: _linkCount,
                isLoading: _isLoadingLinkCount && _linkCount == null,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LinkPage(bid: bid, initialIndex: 0),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              _LinkButton(
                label: '外链',
                icon: Icons.open_in_new,
                showCount: false,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LinkPage(bid: bid, initialIndex: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadLinkCounts() async {
    final bid = _currentBlock.maybeString('bid');
    if (bid == null || bid.isEmpty) {
      return;
    }

    await _loadLinkCount(bid);
  }

  Future<void> _loadLinkCount(String bid) async {
    if (!mounted) return;
    setState(() {
      _isLoadingLinkCount = true;
    });

    int count = _linkCount ?? 0;
    try {
      final api = BlockApi(connectionProvider: context.read<ConnectionProvider>());
      final response = await api.getLinksByTarget(bid: bid, page: 1, limit: 1);
      count = _extractCount(response['data']);
    } catch (_) {
      count = _linkCount ?? 0;
    }

    if (!mounted) return;
    setState(() {
      _linkCount = count;
      _isLoadingLinkCount = false;
    });
  }

  int _extractCount(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final total = payload['total'];
      if (total is int) {
        return total;
      }
      final items = payload['items'];
      if (items is List) {
        return items.length;
      }
    }
    return 0;
  }
}

class _LinkButton extends StatefulWidget {
  const _LinkButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.count,
    this.isLoading = false,
    this.isEnabled = true,
    this.showCount = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;
  final bool isLoading;
  final bool isEnabled;
  final bool showCount;

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _setHovered(bool value) {
    if (!_isInteractive) {
      return;
    }
    if (_isHovered != value) {
      setState(() => _isHovered = value);
    }
  }

  void _setPressed(bool value) {
    if (!_isInteractive) {
      return;
    }
    if (_isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  bool get _isInteractive => widget.isEnabled && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.white.withOpacity(0.08);
    final hoverColor = Colors.white.withOpacity(0.14);
    final pressColor = Colors.white.withOpacity(0.05);

    final background = !_isInteractive
        ? Colors.white.withOpacity(0.04)
        : _isPressed
            ? pressColor
            : _isHovered
                ? hoverColor
                : baseColor;

    final borderColor = Colors.white.withOpacity(
      !_isInteractive
          ? 0.12
          : _isHovered
              ? 0.28
              : 0.18,
    );

    final gradient = LinearGradient(
      colors: [
        Colors.white.withOpacity(!_isInteractive
            ? 0.04
            : _isHovered
                ? 0.16
                : 0.08),
        Colors.white.withOpacity(!_isInteractive
            ? 0.01
            : _isHovered
                ? 0.04
                : 0.02),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final textColor = !_isInteractive ? Colors.white38 : Colors.white;
    final badgeBackground = Colors.white.withOpacity(!_isInteractive ? 0.08 : 0.16);
    final badgeTextColor = !_isInteractive ? Colors.white54 : Colors.white;
    final displayCount = widget.count ?? 0;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) {
          _setPressed(false);
          if (_isInteractive) {
            widget.onTap();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.7),
            color: background,
            gradient: gradient,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: textColor, size: 18),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              if (widget.showCount) ...[
                const SizedBox(width: 12),
                if (widget.isLoading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      displayCount.toString(),
                      style: TextStyle(
                        color: badgeTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
