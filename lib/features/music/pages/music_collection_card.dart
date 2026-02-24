import 'package:flutter/material.dart';

import '../models/music_models.dart';

/// 音乐集合卡片组件
class MusicCollectionCard extends StatelessWidget {
  const MusicCollectionCard({
    super.key,
    required this.collection,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  final MusicCollection collection;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    collection.title ?? collection.bid,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (collection.isPlaylist)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_play, size: 12, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          '已加入播放',
                          style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (collection.intro != null && collection.intro!.isNotEmpty)
              Text(
                collection.intro!,
                style: TextStyle(
                  color: isSelected ? Colors.white70 : Colors.white54,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

