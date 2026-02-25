import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../blocks/file/models/file_card_data.dart';
import '../../../blocks/file/pages/file_edit_page.dart';
import '../../../blocks/file/widgets/image_file_card.dart';
import '../../../blocks/gps/pages/gps_edit_page.dart';
import '../../../blocks/gps/widgets/gps_simple.dart';
import '../../../core/routing/app_router.dart';
import '../../../blocks/document/widgets/document_simple.dart';
import '../../../core/models/block_model.dart';
import 'package:block_app/core/network/api/block_api.dart';
import '../../../state/connection_provider.dart';
import '../../../core/utils/generators/bid_generator.dart';
import '../../../core/utils/formatters/time_formatter.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';

import '../services/trace_settings_manager.dart';

/// 痕迹记录列表页面，仅展示 UI
class TraceRecordPage extends StatelessWidget {
  const TraceRecordPage({super.key, required this.showGps});

  final bool showGps;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _GradientBackground(),
        _RecordList(showGps: showGps),
        const _CreationOptionsBar(),
      ],
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black, child: const SizedBox.expand());
  }
}

class _RecordList extends StatefulWidget {
  const _RecordList({required this.showGps});

  final bool showGps;

  @override
  State<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends State<_RecordList> {
  final ScrollController _scrollController = ScrollController();
  final List<BlockModel> _records = [];

  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 20;
  String? _traceBid;

  @override
  void initState() {
    super.initState();
    _loadTraceBidAndPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_RecordList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 showGps 状态改变时，刷新列表
    if (oldWidget.showGps != widget.showGps) {
      _loadPage(refresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadPage();
    }
  }

  Future<void> _loadTraceBidAndPage() async {
    final bid = await TraceSettingsManager.loadTraceNodeBid();
    setState(() => _traceBid = bid.trim().isEmpty ? null : bid.trim());
    await _loadPage(refresh: true);
  }

  Future<void> _loadPage({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (refresh) {
        _page = 1;
        _hasMore = true;
        _records.clear();
      }

      if (!_hasMore) return;

      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      final response = await api.getAllBlocks(
        page: _page,
        limit: _pageSize,
        order: 'desc',
        receiverBid: _traceBid != null && _traceBid!.length >= 10
            ? _traceBid!.substring(0, 10)
            : null,
        excludeModels: widget.showGps ? null : ['5b877cf0259538958f4ce032a1de7ae7'],
      );

      final dataMap = response['data'];
      if (dataMap is Map<String, dynamic>) {
        final items = dataMap['items'];
        if (items is List) {
          final fetched = items
              .whereType<Map<String, dynamic>>()
              .map((data) => BlockModel(data: Map<String, dynamic>.from(data)))
              .where(_isSupportedModel)
              .toList();

          setState(() {
            _records.addAll(fetched);
            if (items.length < _pageSize) {
              _hasMore = false;
            } else {
              _page += 1;
            }
          });
        } else {
          setState(() => _hasMore = false);
        }
      } else {
        setState(() => _hasMore = false);
      }
    } catch (error) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadPage(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.white,
      backgroundColor: Colors.black,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
        physics: const BouncingScrollPhysics(),
        itemCount: _records.isEmpty && !_hasMore
            ? 1
            : _records.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          if (_records.isEmpty && !_hasMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(
                child: Text(
                  '暂无痕迹记录',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            );
          }

          if (index >= _records.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            );
          }
          final block = _records[index];
          final card = _buildCard(block);
          if (card == null) {
            return const SizedBox.shrink();
          }
          return Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: card,
            ),
          );
        },
      ),
    );
  }

  static const String _imageModelId = 'c4238dd0d3d95db7b473adb449f6d282';
  static const String _documentModelId = '93b133932057a254cc15d0f09c91ca98';
  static const String _gpsModelId = '5b877cf0259538958f4ce032a1de7ae7';

  bool _isSupportedModel(BlockModel block) {
    final model = block.maybeString('model');
    if (model == null || model.isEmpty) {
      return false;
    }
    final normalized = model.trim();
    return normalized == _imageModelId ||
        normalized == _documentModelId ||
        normalized == _gpsModelId;
  }

  Widget? _buildCard(BlockModel block) {
    final model = block.maybeString('model')?.trim();
    switch (model) {
      case _imageModelId:
        final data = FileCardData.fromBlock(block);
        return ImageFileCard(block: block, cardData: data);
      case _documentModelId:
        return DocumentSimple(block: block);
      case _gpsModelId:
        return GpsSimple(block: block);
      default:
        return null;
    }
  }
}

class _CreationOptionsBar extends StatelessWidget {
  const _CreationOptionsBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.14),
                    width: 0.6,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _CreationOption(
                        icon: Icons.text_fields_rounded,
                        label: '文本',
                        onTap: () => _openTraceTextDialog(context),
                      ),
                    ),
                    Expanded(
                      child: _CreationOption(
                        icon: Icons.photo_outlined,
                        label: '图片',
                        onTap: () async {
                          final traceBid =
                              await TraceSettingsManager.loadTraceNodeBid();
                          if (traceBid.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请先在痕迹设置中配置节点 BID')),
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  FileEditPage(traceNodeBid: traceBid.trim(), isImageMode: true),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: _CreationOption(
                        icon: Icons.location_on_outlined,
                        label: 'GPS',
                        onTap: () async {
                          final traceBid =
                              await TraceSettingsManager.loadTraceNodeBid();
                          if (traceBid.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请先在痕迹设置中配置节点 BID')),
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  GpsEditPage(traceNodeBid: traceBid.trim()),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTraceTextDialog(BuildContext context) async {
    final navigator = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    final traceBid = await TraceSettingsManager.loadTraceNodeBid();

    if (traceBid.trim().isEmpty) {
      scaffold.showSnackBar(const SnackBar(content: Text('请先在痕迹设置中配置节点 BID')));
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TraceTextDialog(traceBid: traceBid),
    );
  }
}

class _CreationOption extends StatelessWidget {
  const _CreationOption({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TraceTextDialog extends StatefulWidget {
  const _TraceTextDialog({required this.traceBid});

  final String traceBid;

  @override
  State<_TraceTextDialog> createState() => _TraceTextDialogState();
}

class _TraceTextDialogState extends State<_TraceTextDialog> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final scaffold = ScaffoldMessenger.of(context);
    final traceBid = widget.traceBid.trim();
    if (traceBid.length < 10) {
      scaffold.showSnackBar(const SnackBar(content: Text('痕迹节点 BID 无效')));
      return;
    }

    final bid = generateBidV2(traceBid);
    final now = nowIso8601WithOffset();
    final payload = {
      'bid': bid,
      'model': '93b133932057a254cc15d0f09c91ca98',
      'name': '',
      'content': _contentController.text.trim(),
      'permission_level': 0,
      'tag': <String>[],
      'link': <String>[],
      'add_time': now,
    };

    setState(() => _isSubmitting = true);

    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      await api.saveBlock(data: payload, receiverBid: traceBid);
      if (!mounted) return;

      scaffold.showSnackBar(const SnackBar(content: Text('痕迹文本已创建')));
      Navigator.of(context).pop();
      AppRouter.openBlockDetailPage(context, BlockModel(data: payload));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      scaffold.showSnackBar(SnackBar(content: Text('创建失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '创建痕迹文本',
      content: Form(
        key: _formKey,
        child: AppDialogTextField(
          controller: _contentController,
          hintText: '输入内容（必填）',
          minLines: 4,
          maxLines: 10,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '内容不能为空';
            }
            return null;
          },
        ),
      ),
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建'),
          ),
        ],
      ),
    );
  }
}
