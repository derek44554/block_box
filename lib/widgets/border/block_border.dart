import 'package:flutter/material.dart';

enum BlockBorderStyle {
  cornerBreak,
}

class BlockBorder extends StatelessWidget {
  const BlockBorder({
    super.key,
    required this.child,
    this.style = BlockBorderStyle.cornerBreak,
    this.strokeWidth = 1.0,
    this.color = Colors.white,
    this.cornerGap = 8,
    this.cornerStrokeWidth = 2.0,
    this.cornerLength = 10,
  });

  final Widget child;
  final BlockBorderStyle style;
  final double strokeWidth;
  final Color color;
  final double cornerGap;
  final double cornerStrokeWidth;
  final double cornerLength;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case BlockBorderStyle.cornerBreak:
        return CustomPaint(
          foregroundPainter: _CornerBreakBorderPainter(
            color: color,
            strokeWidth: strokeWidth,
            cornerGap: cornerGap,
            cornerStrokeWidth: cornerStrokeWidth,
            cornerLength: cornerLength,
          ),
          child: child,
        );
    }
  }
}

class _CornerBreakBorderPainter extends CustomPainter {
  _CornerBreakBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerGap,
    required this.cornerStrokeWidth,
    required this.cornerLength,
  });

  final Color color;
  final double strokeWidth;
  final double cornerGap;
  final double cornerStrokeWidth;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = cornerStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final halfStroke = strokeWidth / 2;
    final rect = Rect.fromLTRB(
      halfStroke,
      halfStroke,
      size.width - halfStroke,
      size.height - halfStroke,
    );

    // 绘制四条主边，每条边都在角落处断开，与角落L形线条分离
    final gap = cornerGap + cornerLength;
    
    // 上边：从左角结束到右角开始
    canvas.drawLine(
      Offset(rect.left + gap, rect.top),
      Offset(rect.right - gap, rect.top),
      paint,
    );

    // 下边：从左角结束到右角开始
    canvas.drawLine(
      Offset(rect.left + gap, rect.bottom),
      Offset(rect.right - gap, rect.bottom),
      paint,
    );

    // 左边：从上角结束到下角开始
    canvas.drawLine(
      Offset(rect.left, rect.top + gap),
      Offset(rect.left, rect.bottom - gap),
      paint,
    );

    // 右边：从上角结束到下角开始
    canvas.drawLine(
      Offset(rect.right, rect.top + gap),
      Offset(rect.right, rect.bottom - gap),
      paint,
    );

    // 绘制四个角的L形线条
    // 左上角
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.top + cornerLength),
      cornerPaint,
    );

    // 右上角
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right - cornerLength, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // 左下角
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.bottom - cornerLength),
      cornerPaint,
    );

    // 右下角
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - cornerLength, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBreakBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerGap != cornerGap ||
        oldDelegate.cornerStrokeWidth != cornerStrokeWidth ||
        oldDelegate.cornerLength != cornerLength;
  }
}

