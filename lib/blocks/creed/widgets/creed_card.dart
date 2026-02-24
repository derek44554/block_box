import 'package:flutter/material.dart';
import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/routing/app_router.dart';

/// 信条卡片组件
///
/// 用于在列表中显示信条类型的Block，只显示content内容
class CreedCard extends StatelessWidget {
  const CreedCard({
    super.key,
    required this.block,
    this.onTap,
  });

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = block.maybeString('content') ?? '无内容';
    final bid = block.maybeString('bid');
    final addTime = _resolveAddTime();
    final tags = _resolveTags();

    return GestureDetector(
      onTap: onTap ?? () {
        AppRouter.openBlockDetailPage(context, block);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111112),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 信条图标和标识
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D4A22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.format_quote,
                    color: Color(0xFF4CAF50),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '信条',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 信条内容
            Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            // 标签显示
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTags(tags),
            ],
            const SizedBox(height: 16),
            // 底部信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (bid != null)
                  Text(
                    formatBid(bid),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                if (addTime != null)
                  Text(
                    addTime,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveAddTime() {
    final addTimeValue = block.data['add_time'];
    if (addTimeValue is DateTime) {
      return formatDate(addTimeValue);
    }
    if (addTimeValue is String && addTimeValue.trim().isNotEmpty) {
      return addTimeValue;
    }

    final createdAt = block.getDateTime('createdAt');
    if (createdAt != null) {
      return formatDate(createdAt);
    }
    return null;
  }

  /// 解析标签
  List<String> _resolveTags() {
    return _extractTags(block.data);
  }

  /// 从数据中提取标签
  List<String> _extractTags(Map<String, dynamic> data) {
    final tagValue = data['tag'];
    if (tagValue is List) {
      return tagValue
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final tagsValue = data['tags'];
    if (tagsValue is List) {
      return tagsValue
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// 构建标签显示
  Widget _buildTags(List<String> tags) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.take(3).map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            color: Color(0xFF4CAF50),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      )).toList(),
    );
  }
}