import 'package:flutter/material.dart';

enum ArticleBorderStyle {
  geometric,
}

class ArticleBorder extends StatelessWidget {
  const ArticleBorder({
    super.key,
    required this.child,
    this.style = ArticleBorderStyle.geometric,
    this.strokeWidth = 0.8,
    this.color = Colors.white,
    this.cornerRadius = 16.0,
    this.cornerLineLength = 12.0,
    this.accentLineLength = 20.0,
  });

  final Widget child;
  final ArticleBorderStyle style;
  final double strokeWidth;
  final Color color;
  final double cornerRadius;
  final double cornerLineLength;
  final double accentLineLength;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ArticleBorderStyle.geometric:
        return CustomPaint(
          foregroundPainter: _GeometricArticleBorderPainter(
            strokeWidth: strokeWidth,
            color: color,
            cornerRadius: cornerRadius,
            cornerLineLength: cornerLineLength,
            accentLineLength: accentLineLength,
          ),
          child: child,
        );
    }
  }
}

class _GeometricArticleBorderPainter extends CustomPainter {
  _GeometricArticleBorderPainter({
    required this.strokeWidth,
    required this.color,
    required this.cornerRadius,
    required this.cornerLineLength,
    required this.accentLineLength,
  });

  final double strokeWidth;
  final Color color;
  final double cornerRadius;
  final double cornerLineLength;
  final double accentLineLength;

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.square;

    final accentPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = strokeWidth * 1.15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final detailPaint = Paint()
      ..color = color.withOpacity(0.55)
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

    final bevel = cornerRadius.clamp(6.0, size.shortestSide / 3).toDouble();

    final outerPath = Path()
      ..moveTo(rect.left + bevel, rect.top)
      ..lineTo(rect.right - bevel, rect.top)
      ..lineTo(rect.right, rect.top + bevel)
      ..lineTo(rect.right, rect.bottom - bevel)
      ..lineTo(rect.right - bevel, rect.bottom)
      ..lineTo(rect.left + bevel, rect.bottom)
      ..lineTo(rect.left, rect.bottom - bevel)
      ..lineTo(rect.left, rect.top + bevel)
      ..close();

    canvas.drawPath(outerPath, framePaint);

    final centerX = rect.center.dx;
    final centerY = rect.center.dy;
    final segment = accentLineLength * 0.28;
    final spacing = accentLineLength * 0.24;

    // 顶部/底部中心装饰（水平）
    for (final multiplier in [-1.0, 1.0]) {
      final y = multiplier.isNegative ? rect.top : rect.bottom;
      canvas.drawLine(
        Offset(centerX - spacing - segment, y),
        Offset(centerX - spacing, y),
        accentPaint,
      );
      canvas.drawLine(
        Offset(centerX - segment / 2, y),
        Offset(centerX + segment / 2, y),
        accentPaint,
      );
      canvas.drawLine(
        Offset(centerX + spacing, y),
        Offset(centerX + spacing + segment, y),
        accentPaint,
      );

      final finOffset = strokeWidth * 1.1 * multiplier;
      canvas.drawLine(
        Offset(centerX - segment * 0.55, y + finOffset),
        Offset(centerX - segment * 0.25, y + finOffset),
        detailPaint,
      );
      canvas.drawLine(
        Offset(centerX + segment * 0.25, y + finOffset),
        Offset(centerX + segment * 0.55, y + finOffset),
        detailPaint,
      );
    }

    // 左右中心装饰（垂直）
    for (final multiplier in [-1.0, 1.0]) {
      final x = multiplier.isNegative ? rect.left : rect.right;
      canvas.drawLine(
        Offset(x, centerY - spacing - segment),
        Offset(x, centerY - spacing),
        accentPaint,
      );
      canvas.drawLine(
        Offset(x, centerY - segment / 2),
        Offset(x, centerY + segment / 2),
        accentPaint,
      );
      canvas.drawLine(
        Offset(x, centerY + spacing),
        Offset(x, centerY + spacing + segment),
        accentPaint,
      );

      final finOffset = strokeWidth * 1.1 * multiplier;
      canvas.drawLine(
        Offset(x + finOffset, centerY - segment * 0.55),
        Offset(x + finOffset, centerY - segment * 0.25),
        detailPaint,
      );
      canvas.drawLine(
        Offset(x + finOffset, centerY + segment * 0.25),
        Offset(x + finOffset, centerY + segment * 0.55),
        detailPaint,
      );
    }

    // 内嵌细线，强化结构层次
    final inset = strokeWidth * 3;
    final innerRect = Rect.fromLTRB(
      rect.left + inset,
      rect.top + inset,
      rect.right - inset,
      rect.bottom - inset,
    );

    canvas.drawLine(
      Offset(innerRect.left + bevel * 0.35, innerRect.top),
      Offset(innerRect.right - bevel * 0.35, innerRect.top),
      detailPaint,
    );
    canvas.drawLine(
      Offset(innerRect.left + bevel * 0.35, innerRect.bottom),
      Offset(innerRect.right - bevel * 0.35, innerRect.bottom),
      detailPaint,
    );
    canvas.drawLine(
      Offset(innerRect.left, innerRect.top + bevel * 0.35),
      Offset(innerRect.left, innerRect.bottom - bevel * 0.35),
      detailPaint,
    );
    canvas.drawLine(
      Offset(innerRect.right, innerRect.top + bevel * 0.35),
      Offset(innerRect.right, innerRect.bottom - bevel * 0.35),
      detailPaint,
    );

    // 角落细节线
    final cornerInset = bevel * 0.45;
    final diagonal = cornerLineLength * 0.65;

    for (final horizontal in [-1.0, 1.0]) {
      for (final vertical in [-1.0, 1.0]) {
        final cornerX = horizontal.isNegative ? rect.left : rect.right;
        final cornerY = vertical.isNegative ? rect.top : rect.bottom;

        final start = Offset(
          cornerX + horizontal * (-cornerInset),
          cornerY + vertical * (-strokeWidth * 1.4),
        );
        final end = Offset(
          start.dx + horizontal * (-diagonal),
          start.dy + vertical * (-diagonal * 0.6),
        );
        canvas.drawLine(start, end, detailPaint);

        final crossStart = Offset(
          cornerX + horizontal * (-cornerInset - diagonal * 0.4),
          cornerY + vertical * (-strokeWidth * 2.0),
        );
        final crossEnd = Offset(
          crossStart.dx,
          crossStart.dy + vertical * (-cornerLineLength * 0.55),
        );
        canvas.drawLine(crossStart, crossEnd, detailPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeometricArticleBorderPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.cornerLineLength != cornerLineLength ||
        oldDelegate.accentLineLength != accentLineLength;
  }
}

