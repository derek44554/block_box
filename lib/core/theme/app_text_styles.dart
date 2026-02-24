import 'package:flutter/material.dart';

/// 应用文本样式
///
/// 定义应用中使用的文本样式，保持排版的一致性。
class AppTextStyles {
  const AppTextStyles._();

  // 标题样式
  static const TextStyle headlineSmall = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  // 正文样式
  static const TextStyle bodyMedium = TextStyle(
    color: Colors.white70,
    height: 1.4,
  );
}
