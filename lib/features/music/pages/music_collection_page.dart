import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/connection_provider.dart';
import 'package:block_app/core/network/api/block_api.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';
import 'package:block_app/core/widgets/dialogs/confirmation_dialog.dart';
import '../models/music_models.dart';
import '../providers/music_provider.dart';
import 'music_collection_list.dart';

/// 音乐集合页面，用于管理音乐集合
class MusicCollectionPage extends StatefulWidget {
  const MusicCollectionPage({super.key});

  @override
  State<MusicCollectionPage> createState() => _MusicCollectionPageState();
}

class _MusicCollectionPageState extends State<MusicCollectionPage> {
  int? _selectedCollectionIndex;
  bool _isAddingCollection = false;
  String? _addingError;

  @override
  Widget build(BuildContext context) {
    return Selector<MusicProvider, List<MusicCollection>>(
      selector: (_, provider) => provider.collections,
      builder: (context, collections, _) {
        // 如果没有集合，显示欢迎提示
        if (collections.isEmpty && !_isAddingCollection) {
          return _buildWelcomeView();
        }
        
        return MusicCollectionList(
          collections: collections,
          selectedIndex: _selectedCollectionIndex,
          onToggle: _handleCollectionToggle,
          onAdd: _showAddCollectionDialog,
          onDelete: _confirmDeleteCollection,
          onPlaylistToggle: (bid, isPlaylist) =>
              context.read<MusicProvider>().togglePlaylist(bid, isPlaylist),
          isLoading: _isAddingCollection,
          errorMessage: _addingError,
        );
      },
    );
  }

  Widget _buildWelcomeView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.library_music,
              color: Colors.white24,
              size: 72,
            ),
            const SizedBox(height: 32),
            Text(
              '欢迎使用音乐功能',
              style: TextStyle(
                color: Colors.white.withOpacity(0.87),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '添加音乐集合开始使用',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTipRow('1', '点击下方按钮添加音乐集合（需要集合的 BID）'),
                  const SizedBox(height: 10),
                  _buildTipRow('2', '长按集合，选择"加入播放列表"'),
                  const SizedBox(height: 10),
                  _buildTipRow('3', '在"播放"页面查看和播放音乐'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: OutlinedButton.icon(
                onPressed: _showAddCollectionDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.24)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('添加集合', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  void _handleCollectionToggle(int index) {
    final musicProvider = context.read<MusicProvider>();
    final collections = musicProvider.collections;
    
    setState(() {
      if (_selectedCollectionIndex == index) {
        _selectedCollectionIndex = null;
        musicProvider.setSelectedCollection(null);
      } else {
        _selectedCollectionIndex = index;
        if (index >= 0 && index < collections.length) {
          musicProvider.setSelectedCollection(collections[index].bid);
        }
      }
    });
  }

  void _showAddCollectionDialog() {
    if (_isAddingCollection) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _MusicCollectionDialog(onSubmit: _handleAddCollection),
    );
  }

  Future<void> _handleAddCollection(String bid) async {
    final normalizedBid = bid.trim();
    if (normalizedBid.isEmpty) {
      throw ArgumentError('请输入有效的 BID');
    }

    setState(() {
      _isAddingCollection = true;
      _addingError = null;
    });

    try {
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      final response = await api.getBlock(bid: normalizedBid);
      final data = response['data'];

      if (data is! Map<String, dynamic> || data.isEmpty) {
        throw StateError('未获取到有效的块数据');
      }

      final block = Map<String, dynamic>.from(data);
      final resolvedBid = (block['bid'] as String?)?.trim();
      if (resolvedBid == null || resolvedBid.isEmpty) {
        block['bid'] = normalizedBid;
      }

      final collection = MusicCollection(
        bid: block['bid'] as String,
        block: block,
      );

      await context.read<MusicProvider>().addCollection(collection);

      if (!mounted) {
        return;
      }

      setState(() {
        _addingError = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加 ${collection.title ?? collection.bid}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ArgumentError catch (error) {
      _setAddCollectionError(error.message ?? '参数错误');
      rethrow;
    } on StateError catch (error) {
      _setAddCollectionError(error.message);
      rethrow;
    } catch (error, stack) {
      const message = '加载失败，请稍后重试';
      _setAddCollectionError(message);
      throw StateError(message);
    } finally {
      if (mounted) {
        setState(() {
          _isAddingCollection = false;
        });
      } else {
        _isAddingCollection = false;
      }
    }
  }

  void _setAddCollectionError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _addingError = message;
    });
  }

  Future<void> _confirmDeleteCollection(MusicCollection collection) async {
    final confirm = await showConfirmationDialog(
      context: context,
      title: '确认删除该集合？',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '集合：${collection.title ?? collection.bid}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text(
            '删除后不可恢复，是否继续？',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      confirmText: '删除',
      isDestructive: true,
    );

    if (confirm != true) {
      return;
    }

    await context.read<MusicProvider>().removeCollection(collection.bid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 ${collection.title ?? collection.bid}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _MusicCollectionDialog extends StatefulWidget {
  const _MusicCollectionDialog({required this.onSubmit});

  final Future<void> Function(String bid) onSubmit;

  @override
  State<_MusicCollectionDialog> createState() => _MusicCollectionDialogState();
}

class _MusicCollectionDialogState extends State<_MusicCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bidController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '新增集合',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogTextField(
              controller: _bidController,
              label: '集合 BID',
              hintText: '32 位块 ID',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入集合 BID';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
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
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) {
                        return;
                      }
                      setState(() => _isSubmitting = true);
                      await widget.onSubmit(_bidController.text.trim());
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

