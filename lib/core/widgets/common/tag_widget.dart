import 'package:flutter/material.dart';

import '../../../features/tag/pages/tag_page.dart';


/// 统一标签组件 - 用于显示标签列表
/// 
/// 提供一致的标签样式，支持标签列表显示（Wrap布局）
/// 统一设计风格：黑色主题，白色边框，固定样式
class TagWidget extends StatelessWidget {
  const TagWidget({
    super.key,
    required this.tags,
    this.onAddPressed,
  });

  /// 标签列表
  final List<String> tags;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (final tag in tags)
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TagPage(tag: tag),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      if (onAddPressed != null)
        _DottedTagButton(
          label: '+添加标签',
          onTap: onAddPressed!,
        ),
    ];

    if (onAddPressed == null && children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}

class _DottedTagButton extends StatelessWidget {
  const _DottedTagButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: ShapeDecoration(
          shape: _DashedBorder(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends ShapeBorder {
  const _DashedBorder({required this.color, required this.borderRadius, this.dashWidth = 4, this.gapWidth = 3});

  final Color color;
  final BorderRadius borderRadius;
  final double dashWidth;
  final double gapWidth;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => this;

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => this;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => this;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    path.addRRect(borderRadius.toRRect(rect));
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final rrect = borderRadius.toRRect(rect);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        final extractPath = metric.extractPath(distance, next.clamp(0.0, metric.length));
        canvas.drawPath(extractPath, paint);
        distance = next + gapWidth;
      }
    }
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();
}
