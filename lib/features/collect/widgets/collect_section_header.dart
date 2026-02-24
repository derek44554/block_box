import 'package:flutter/material.dart';

class CollectSectionHeader extends StatelessWidget {
  const CollectSectionHeader({
    super.key,
    required this.title,
    this.onAdd,
    this.isEditing = false,
    this.onToggleEditing,
  });

  final String title;
  final bool isEditing;
  final VoidCallback? onAdd;
  final VoidCallback? onToggleEditing;

  @override
  Widget build(BuildContext context) {
    final indicator = Icon(
      isEditing ? Icons.check_circle : Icons.unfold_more,
      color: Colors.white60,
      size: 16,
    );

    return Row(
      children: [
        GestureDetector(
          onLongPress: onToggleEditing,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isEditing ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                if (onToggleEditing != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onToggleEditing,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: indicator,
                    ),
                  )
                else
                  indicator,
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(width: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white70, size: 16),
            ),
          ),
        ],
      ],
    );
  }
}

