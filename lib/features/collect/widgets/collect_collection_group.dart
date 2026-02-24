import 'package:flutter/material.dart';

import '../models/collect_models.dart';


class CollectCollectionGroupWidget extends StatelessWidget {
  const CollectCollectionGroupWidget({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onItemTap,
    required this.onAdd,
    required this.onDeleteItem,
    this.isEditing = false,
    this.onReorderItems,
    this.onHeaderOptions,
    this.dragIndex,
  });

  final CollectEntry entry;
  final bool Function(CollectItem item) isSelected;
  final void Function(String entryId, CollectItem item) onItemTap;
  final VoidCallback onAdd;
  final void Function(CollectItem item) onDeleteItem;
  final bool isEditing;
  final void Function(int oldIndex, int newIndex)? onReorderItems;
  final Future<void> Function()? onHeaderOptions;
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: entry.title,
          onAdd: onAdd,
          onOptions: onHeaderOptions,
          dragIndex: dragIndex,
          enableReorder: isEditing,
        ),
        const SizedBox(height: 12),
        if (entry.items.isEmpty)
          const Text(
            '暂无内容',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          )
        else
          _buildItems(context),
      ],
    );
  }

  Widget _buildItems(BuildContext context) {
    if (!isEditing || onReorderItems == null) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var index = 0; index < entry.items.length; index++)
            _InteractiveItemChip(
              key: ValueKey('${entry.id}_${entry.items[index].bid}_$index'),
              title: entry.items[index].name,
              isActive: isSelected(entry.items[index]),
              showHandle: false,
              onTap: () => onItemTap(entry.id, entry.items[index]),
              onDelete: onDeleteItem,
              item: entry.items[index],
            ),
        ],
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: onReorderItems!,
      itemCount: entry.items.length,
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final item = entry.items[index];
        return Padding(
          key: ValueKey('${entry.id}_${item.bid}_$index'),
          padding: const EdgeInsets.only(bottom: 10),
          child: ReorderableDragStartListener(
            index: index,
            child: _InteractiveItemChip(
              title: item.name,
              isActive: isSelected(item),
              showHandle: true,
              onTap: () => onItemTap(entry.id, item),
              onDelete: onDeleteItem,
              item: item,
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onAdd,
    this.onOptions,
    this.dragIndex,
    this.enableReorder = false,
  });

  final String title;
  final VoidCallback onAdd;
  final Future<void> Function()? onOptions;
  final int? dragIndex;
  final bool enableReorder;

  @override
  Widget build(BuildContext context) {
    final titleWidget = GestureDetector(
      onLongPress: onOptions,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    return Row(
      children: [
        if (enableReorder && dragIndex != null) ...[
          ReorderableDragStartListener(
            index: dragIndex!,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.drag_indicator,
                color: Colors.white30,
                size: 18,
              ),
            ),
          ),
        ],
        Expanded(child: titleWidget),
        IconButton(
          splashRadius: 18,
          icon: const Icon(Icons.add, color: Colors.white60, size: 18),
          onPressed: onAdd,
        ),
        IconButton(
          splashRadius: 18,
          icon: const Icon(Icons.more_horiz, color: Colors.white38, size: 18),
          onPressed: onOptions == null ? null : () => onOptions?.call(),
        ),
      ],
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({
    required this.title,
    required this.isActive,
    required this.showHandle,
  });

  final String title;
  final bool isActive;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withOpacity(0.18)
            : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? Colors.white70 : Colors.white10,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          if (showHandle) const SizedBox(width: 6),
          if (showHandle)
            const Icon(Icons.drag_indicator, color: Colors.white30, size: 16),
        ],
      ),
    );
  }
}

class _InteractiveItemChip extends StatelessWidget {
  const _InteractiveItemChip({
    super.key,
    required this.title,
    required this.isActive,
    required this.showHandle,
    required this.onTap,
    required this.onDelete,
    required this.item,
  });

  final String title;
  final bool isActive;
  final bool showHandle;
  final VoidCallback onTap;
  final void Function(CollectItem item) onDelete;
  final CollectItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: showHandle ? null : () => onDelete(item),
      child: _ItemChip(
        title: title,
        isActive: isActive,
        showHandle: showHandle,
      ),
    );
  }
}
