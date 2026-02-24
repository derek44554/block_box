import 'package:flutter/material.dart';

enum DocumentBorderStyle {
  minimal,
}

class DocumentBorder extends StatelessWidget {
  const DocumentBorder({
    super.key,
    required this.child,
    this.style = DocumentBorderStyle.minimal,
    this.strokeWidth = 0.8,
    this.color = Colors.white,
    this.cornerRadius = 6.0,
    this.dashLength = 4.0,
    this.dashGap = 3.0,
  });

  final Widget child;
  final DocumentBorderStyle style;
  final double strokeWidth;
  final Color color;
  final double cornerRadius;
  final double dashLength;
  final double dashGap;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case DocumentBorderStyle.minimal:
        return CustomPaint(
          foregroundPainter: _MinimalDocumentBorderPainter(
            color: color,
            strokeWidth: strokeWidth,
            cornerRadius: cornerRadius,
            dashLength: dashLength,
            dashGap: dashGap,
          ),
          child: child,
        );
    }
  }
}

class _MinimalDocumentBorderPainter extends CustomPainter {
  _MinimalDocumentBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerRadius,
    required this.dashLength,
    required this.dashGap,
  });

  final Color color;
  final double strokeWidth;
  final double cornerRadius;
  final double dashLength;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final halfStroke = strokeWidth / 2;
    final rect = Rect.fromLTRB(
      halfStroke,
      halfStroke,
      size.width - halfStroke,
      size.height - halfStroke,
    );

    // 绘制虚线边框
    _drawDashedRect(canvas, rect, paint);

    // 在四个角绘制小圆点作为装饰
    final dotPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final dotRadius = strokeWidth * 1.5;
    final dotOffset = cornerRadius * 0.7;

    // 四个角的装饰点
    canvas.drawCircle(
      Offset(rect.left + dotOffset, rect.top + dotOffset),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(rect.right - dotOffset, rect.top + dotOffset),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(rect.left + dotOffset, rect.bottom - dotOffset),
      dotRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(rect.right - dotOffset, rect.bottom - dotOffset),
      dotRadius,
      dotPaint,
    );
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    // 上边
    _drawDashedLine(
      canvas,
      Offset(rect.left + cornerRadius, rect.top),
      Offset(rect.right - cornerRadius, rect.top),
      paint,
    );

    // 下边
    _drawDashedLine(
      canvas,
      Offset(rect.left + cornerRadius, rect.bottom),
      Offset(rect.right - cornerRadius, rect.bottom),
      paint,
    );

    // 左边
    _drawDashedLine(
      canvas,
      Offset(rect.left, rect.top + cornerRadius),
      Offset(rect.left, rect.bottom - cornerRadius),
      paint,
    );

    // 右边
    _drawDashedLine(
      canvas,
      Offset(rect.right, rect.top + cornerRadius),
      Offset(rect.right, rect.bottom - cornerRadius),
      paint,
    );

    // 绘制圆角
    final cornerPaint = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 左上角
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(rect.left + cornerRadius, rect.top + cornerRadius),
        radius: cornerRadius,
      ),
      3.14159, // 180度
      1.5708, // 90度
      false,
      cornerPaint,
    );

    // 右上角
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(rect.right - cornerRadius, rect.top + cornerRadius),
        radius: cornerRadius,
      ),
      4.71239, // 270度
      1.5708, // 90度
      false,
      cornerPaint,
    );

    // 左下角
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(rect.left + cornerRadius, rect.bottom - cornerRadius),
        radius: cornerRadius,
      ),
      1.5708, // 90度
      1.5708, // 90度
      false,
      cornerPaint,
    );

    // 右下角
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(rect.right - cornerRadius, rect.bottom - cornerRadius),
        radius: cornerRadius,
      ),
      0, // 0度
      1.5708, // 90度
      false,
      cornerPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final distance = (end - start).distance;
    final dashCount = (distance / (dashLength + dashGap)).floor();
    final direction = (end - start) / distance;

    for (int i = 0; i < dashCount; i++) {
      final dashStart = start + direction * (i * (dashLength + dashGap));
      final dashEnd = dashStart + direction * dashLength;
      canvas.drawLine(dashStart, dashEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimalDocumentBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.dashGap != dashGap;
  }
}
