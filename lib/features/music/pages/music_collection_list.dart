import 'package:flutter/material.dart';
import '../models/music_models.dart';
import 'music_collection_card.dart';
import '../../../core/widgets/common/action_sheet.dart';

/// 音乐集合列表组件
class MusicCollectionList extends StatelessWidget {
  const MusicCollectionList({
    super.key,
    required this.collections,
    required this.selectedIndex,
    required this.onToggle,
    required this.onAdd,
    required this.onDelete,
    required this.onPlaylistToggle,
    this.isLoading = false,
    this.errorMessage,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 32),
  });

  final List<MusicCollection> collections;
  final int? selectedIndex;
  final ValueChanged<int> onToggle;
  final VoidCallback onAdd;
  final void Function(MusicCollection collection) onDelete;
  final void Function(String bid, bool isPlaylist) onPlaylistToggle;
  final bool isLoading;
  final String? errorMessage;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, padding.bottom + 96),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (isLoading)
                const SliverToBoxAdapter(child: _CollectionStateView.loading())
              else if (errorMessage != null)
                SliverToBoxAdapter(child: _CollectionStateView.error(message: errorMessage!))
              else if (collections.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CollectionStateView.empty(),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final collection = collections[index];
                      final isSelected = selectedIndex == index;
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == collections.length - 1 ? 0 : 16),
                        child: MusicCollectionCard(
                          collection: collection,
                          isSelected: isSelected,
                          onTap: () => onToggle(index),
                          onLongPress: () => _showCollectionActions(
                            context,
                            collection,
                            onPlaylistToggle: onPlaylistToggle,
                            onDelete: onDelete,
                          ),
                        ),
                      );
                    },
                    childCount: collections.length,
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: padding.left,
          right: padding.right,
          bottom: padding.bottom,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onAdd,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(color: Colors.white.withOpacity(0.16)),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加集合', style: TextStyle(letterSpacing: 0.6)),
          ),
        ),
      ],
    );
  }
}

void _showCollectionActions(
  BuildContext context,
  MusicCollection collection, {
  required void Function(String bid, bool isPlaylist) onPlaylistToggle,
  required void Function(MusicCollection collection) onDelete,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => ActionSheet(
      title: collection.title ?? collection.bid,
      actions: [
        if (collection.isPlaylist)
          ActionItem(
            label: '从播放列表移除',
            icon: Icons.remove_circle_outline,
            onTap: () {
              Navigator.of(context).pop();
              onPlaylistToggle(collection.bid, false);
            },
          )
        else
          ActionItem(
            label: '加入播放列表',
            icon: Icons.playlist_add,
            onTap: () {
              Navigator.of(context).pop();
              onPlaylistToggle(collection.bid, true);
            },
          ),
        ActionItem(
          label: '删除集合',
          icon: Icons.delete_outline,
          isDestructive: true,
          onTap: () {
            Navigator.of(context).pop();
            onDelete(collection);
          },
        ),
      ],
    ),
  );
}

class _CollectionStateView extends StatelessWidget {
  const _CollectionStateView.loading()
      : message = '正在加载集合…',
        icon = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        color = Colors.white60;

  const _CollectionStateView.empty()
      : message = '暂无集合',
        icon = const Icon(Icons.inbox_outlined, size: 18, color: Colors.white38),
        color = Colors.white38;

  const _CollectionStateView.error({required this.message})
      : icon = const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
        color = Colors.redAccent;

  final String message;
  final Widget icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48, bottom: 24),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              message,
              style: TextStyle(color: color, fontSize: 12, letterSpacing: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

