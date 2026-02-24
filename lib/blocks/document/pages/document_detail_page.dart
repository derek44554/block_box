import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/block_model.dart';
import 'package:block_app/core/network/api/block_api.dart';
import '../../../features/link/pages/link_page.dart';
import '../../common/block_detail_page.dart';
import '../../../state/connection_provider.dart';
import '../../../state/block_provider.dart';

// 文档详情页面
class DocumentDetailPage extends StatefulWidget {
  DocumentDetailPage({super.key, this.block, this.bid})
      : assert(block != null || (bid != null && bid.isNotEmpty), 'block 或 bid 必须至少提供一个');

  final BlockModel? block;
  final String? bid;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;
  late final FocusNode _titleFocusNode;
  bool _isKeyboardVisible = false;
  bool _hasChanges = false;
  bool _isSubmitting = false;
  late String _originalTitle;
  late String _originalContent;
  late Map<String, dynamic> _blockData;
  bool _isInitializing = true;
  int _linkCount = 0;
  bool _isLinkLoading = false;
  VoidCallback? _blockProviderListener;

  String get _effectiveBid {
    if (_blockData.containsKey('bid')) {
      final value = _blockData['bid'];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    if (widget.block != null) {
      final bid = widget.block!.maybeString('bid');
      if (bid != null && bid.isNotEmpty) {
        return bid;
      }
    }
    return widget.bid ?? '';
  }

  int _extractLinkCount(Map<String, dynamic> data) {
    final linkValue = data['link'];
    if (linkValue is Map<String, dynamic>) {
      final items = linkValue['items'];
      if (items is List) {
        return items.length;
      }
      final total = linkValue['total'];
      if (total is int) {
        return total;
      }
    }
    if (linkValue is List) {
      return linkValue.length;
    }
    return 0;
  }

  String _normalizeText(String value) => value.replaceAll('\r\n', '\n').trim();

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.block?.maybeString('name') ?? '')
          ..addListener(_trackChanges);
    _contentController =
        TextEditingController(text: widget.block?.maybeString('content') ?? '')
          ..addListener(_trackChanges);
    if (widget.block != null) {
      _blockData = Map<String, dynamic>.from(widget.block!.data);
    } else {
      _blockData = widget.bid != null && widget.bid!.isNotEmpty
          ? {'bid': widget.bid}
          : <String, dynamic>{};
    }
    _originalTitle = _normalizeText(_titleController.text);
    _originalContent = _normalizeText(_contentController.text);
    _linkCount = widget.block != null ? _extractLinkCount(widget.block!.data) : 0;
    _contentFocusNode = FocusNode();
    _titleFocusNode = FocusNode();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isInitializing = false);
        _refreshLinkCount();
        
        // Listen to BlockProvider for updates
        _blockProviderListener = _onBlockProviderUpdate;
        context.read<BlockProvider>().addListener(_blockProviderListener!);
        debugPrint('DocumentDetailPage: Added BlockProvider listener for BID: $_effectiveBid');
      }
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_trackChanges);
    _contentController.removeListener(_trackChanges);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _titleFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    
    // Remove BlockProvider listener
    if (_blockProviderListener != null) {
      try {
        context.read<BlockProvider>().removeListener(_blockProviderListener!);
        debugPrint('DocumentDetailPage: Removed BlockProvider listener');
      } catch (e) {
        debugPrint('DocumentDetailPage: Error removing BlockProvider listener: $e');
      }
      _blockProviderListener = null;
    }
    
    super.dispose();
  }

  /// Handle BlockProvider updates
  void _onBlockProviderUpdate() {
    if (!mounted || _isSubmitting) return;
    
    final bid = _effectiveBid;
    if (bid.isEmpty) return;
    
    try {
      final blockProvider = context.read<BlockProvider>();
      final updatedBlock = blockProvider.getBlock(bid);
      
      if (updatedBlock != null) {
        debugPrint('DocumentDetailPage: Received updated Block from BlockProvider for BID: $bid');
        
        // Only update if user is not currently editing
        if (!_hasChanges && !_titleFocusNode.hasFocus && !_contentFocusNode.hasFocus) {
          setState(() {
            _blockData = Map<String, dynamic>.from(updatedBlock.data);
            final newTitle = updatedBlock.maybeString('name') ?? '';
            final newContent = updatedBlock.maybeString('content') ?? '';
            
            _titleController.text = newTitle;
            _contentController.text = newContent;
            _originalTitle = _normalizeText(newTitle);
            _originalContent = _normalizeText(newContent);
            _linkCount = _extractLinkCount(updatedBlock.data);
          });
          debugPrint('DocumentDetailPage: UI updated with latest Block data');
        } else {
          debugPrint('DocumentDetailPage: Skipped update because user is editing');
        }
      }
    } catch (e) {
      debugPrint('DocumentDetailPage: Error in _onBlockProviderUpdate: $e');
    }
  }

  void _trackChanges() {
    final changed =
        _normalizeText(_titleController.text) != _originalTitle ||
            _normalizeText(_contentController.text) != _originalContent;
    if (!_isInitializing && changed != _hasChanges && mounted) {
      setState(() => _hasChanges = changed);
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) {
      final isKeyboardCurrentlyVisible =
          MediaQuery.of(context).viewInsets.bottom > 0;

      if (_isKeyboardVisible &&
          !isKeyboardCurrentlyVisible &&
          (_titleFocusNode.hasFocus || _contentFocusNode.hasFocus)) {
        FocusScope.of(context).unfocus();
      }
      _isKeyboardVisible = isKeyboardCurrentlyVisible;
    }
  }

  Future<void> _submitChanges() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容为空，无法提交')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);

      final payload = Map<String, dynamic>.from(_blockData);
      if (!payload.containsKey('bid') && _effectiveBid.isNotEmpty) {
        payload['bid'] = _effectiveBid;
      }
      payload
        ..['model'] = payload['model'] ?? '93b133932057a254cc15d0f09c91ca98'
        ..['type'] = payload['type'] ?? 'document'
        ..['name'] = title
        ..['content'] = content;

      await api.saveBlock(data: payload);

      if (!mounted) return;

      setState(() {
        _blockData = payload;
        final blockModel = BlockModel(data: Map<String, dynamic>.from(payload));
        _originalTitle = _normalizeText(blockModel.maybeString('name') ?? '');
        _originalContent = _normalizeText(blockModel.maybeString('content') ?? '');
        _titleController
          ..removeListener(_trackChanges)
          ..text = blockModel.maybeString('name') ?? ''
          ..addListener(_trackChanges);
        _contentController
          ..removeListener(_trackChanges)
          ..text = blockModel.maybeString('content') ?? ''
          ..addListener(_trackChanges);
        _linkCount = _extractLinkCount(blockModel.data);
        _isSubmitting = false;
        _hasChanges = false;
      });
      
      // Update BlockProvider to notify all listening pages (including list pages)
      // BlockProvider automatically notifies all listeners (including list pages)
      final blockProvider = context.read<BlockProvider>();
      final blockToUpdate = BlockModel(data: Map<String, dynamic>.from(payload));
      debugPrint('DocumentDetailPage: Updating BlockProvider with BID: ${blockToUpdate.bid}');
      blockProvider.updateBlock(blockToUpdate);
      debugPrint('DocumentDetailPage: BlockProvider updated, cache size: ${blockProvider.cacheSize}');
      
      await _refreshLinkCount();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：$error')),
      );
      setState(() => _isSubmitting = false);
    }
  }


  Future<void> _refreshLinkCount() async {
    final bid = _effectiveBid;
    if (bid.isEmpty) {
      return;
    }
    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      if (mounted) {
        setState(() => _isLinkLoading = true);
      }
      final response = await api.getLinksByTarget(bid: bid);
      final data = response['data'];
      int count = 0;
      if (data is Map<String, dynamic>) {
        final items = data['items'];
        if (items is List) {
          count = items.length;
        } else {
          final total = data['total'];
          if (total is int) {
            count = total;
          }
        }
      }
      if (mounted) {
        setState(() {
          _linkCount = count;
          _isLinkLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Failed to refresh link count: $error');
      if (mounted) {
        setState(() => _isLinkLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTitleEmpty = _titleController.text.isEmpty;
    final topPadding = isTitleEmpty ? 0.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: _isInitializing
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlockDetailPage(
                            block: widget.block ?? BlockModel(data: Map<String, dynamic>.from(_blockData)),
                          ),
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
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, topPadding, 24, 0),
                            child: TextField(
                              controller: _titleController,
                              focusNode: _titleFocusNode,
                              enabled: !_isSubmitting && !_isInitializing,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _titleController.text.isEmpty == true ? 12 : 18,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              decoration: InputDecoration(
                                hintText: '',
                                hintStyle: TextStyle(
                                  color: Colors.white30,
                                  fontSize:
                                      _titleController.text.isEmpty == true ? 12 : 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                filled: false,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ),
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _contentFocusNode.requestFocus(),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                              child: TextField(
                                controller: _contentController,
                                focusNode: _contentFocusNode,
                                enabled: !_isSubmitting && !_isInitializing,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.7,
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '在这里输入内容...',
                                  hintStyle: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 14,
                                    height: 1.7,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  filled: false,
                                ),
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (!_isKeyboardVisible && !_isInitializing)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 24, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_hasChanges || _isSubmitting) ...[
                        _buildSubmitButton(),
                        const SizedBox(height: 12),
                      ],
                      _LinkBadge(
                        count: _linkCount,
                        onTap: _openLinkPage,
                        isEnabled: _effectiveBid.isNotEmpty && !_isLinkLoading,
                        isLoading: _isLinkLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isEnabled = _hasChanges && !_isSubmitting;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            spreadRadius: 0.5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isEnabled ? _submitChanges : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  )
                : Icon(
                    Icons.done_rounded,
                    color: isEnabled ? Colors.white : Colors.white38,
                    size: 18,
                  ),
          ),
        ),
      ),
    );
  }

  void _openLinkPage() {
    final bid = _effectiveBid;
    if (bid.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LinkPage(bid: bid),
      ),
    );
  }
}

class _LinkBadge extends StatelessWidget {
  const _LinkBadge({
    required this.count,
    required this.onTap,
    required this.isEnabled,
    required this.isLoading,
  });

  final int count;
  final VoidCallback onTap;
  final bool isEnabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final color = isEnabled ? Colors.white : Colors.white38;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12, width: 0.6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                spreadRadius: 0.5,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
