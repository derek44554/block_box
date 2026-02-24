import 'package:flutter/material.dart';

import '../../../core/widgets/common/tag_widget.dart';

class BlockHeader extends StatelessWidget {
  const BlockHeader({
    super.key,
    this.title,
    this.name,
    this.intro,
    required this.tags,
    this.onAddTag,
    this.alwaysShowTags = false,
    required this.quickActions,
    this.addTime,
  });

  final String? title;
  final String? name;
  final String? intro;
  final List<String> tags;
  final VoidCallback? onAddTag;
  final bool alwaysShowTags;
  final Widget quickActions;
  final String? addTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '块',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 15,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 18),
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                height: 1.15,
              ),
            ),
          if (name != null)
            Text(
              name!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                height: 1.15,
              ),
            ),
          if (intro != null) ...[
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                intro!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 17,
                  height: 1.7,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          quickActions,
          if (addTime != null) ...[
            const SizedBox(height: 16),
            Text(
              '添加时间 $addTime',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ],
          if (alwaysShowTags || tags.isNotEmpty) ...[
            const SizedBox(height: 50),
            const Text(
              '标签',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 12),
            TagWidget(
              tags: tags,
              onAddPressed: onAddTag,
            ),
          ],
        ],
      ),
    );
  }
}

