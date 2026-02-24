import 'package:flutter/material.dart';
import '../models/photo_models.dart';
import 'photo_card.dart';

typedef PhotoTapCallback = void Function(int index);

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.photos,
    required this.onTap,
    this.spacing = 6.0,
    this.horizontalPadding = 14.0,
    this.minItemWidth = 100.0,
  });

  final List<PhotoImage> photos;
  final PhotoTapCallback onTap;
  final double spacing;
  final double horizontalPadding;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据屏幕宽度自动计算每行显示的照片数量
        final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
        int crossAxisCount = ((availableWidth + spacing) / (minItemWidth + spacing)).floor();
        
        // 确保至少显示 2 列，最多显示 8 列
        crossAxisCount = crossAxisCount.clamp(2, 8);
        
        final totalSpacing = spacing * (crossAxisCount - 1);
        final actualAvailableWidth = constraints.maxWidth - (horizontalPadding * 2) - totalSpacing;
        final itemSize = actualAvailableWidth / crossAxisCount;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = photos[index];
                    return PhotoCard(
                      item: item,
                      size: itemSize,
                      onTap: () => onTap(index),
                    );
                  },
                  childCount: photos.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

