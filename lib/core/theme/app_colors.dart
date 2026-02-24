import 'package:flutter/material.dart';

/// 应用颜色常量
///
/// 定义应用中使用的所有颜色，保持视觉风格的一致性。
/// 主题：深色主题，黑色背景，灰色系主色调。
class AppColors {
  const AppColors._();

  // 主色调
  static const Color primary = Color(0xFF9E9EA2);
  static const Color secondary = Color(0xFFB5B5B9);
  static const Color tertiary = Color(0xFF767679);

  // 表面颜色
  static const Color surface = Color(0xFF121214);
  static const Color background = Colors.black;
  static const Color scaffoldBackground = Colors.black;

  // 文本颜色
  static const Color onPrimary = Colors.black;
  static const Color onSecondary = Colors.black;
  static const Color onTertiary = Colors.white;
  static const Color onSurface = Colors.white;
  static const Color onBackground = Colors.white;

  // 输入框颜色
  static const Color inputFill = Color(0xFF1C1C1F);
  static const Color inputHint = Color(0xFF6F6F73);
  static const Color inputBorder = Color(0xFF2E2E32);
  static const Color inputFocusedBorder = Color(0xFF9E9EA2);

  // 错误颜色
  static const Color error = Color(0xFFFF5C5C);
  static const Color errorFocused = Color(0xFFFF8181);

  // 按钮颜色
  static const Color buttonBackground = Color(0xFF2F2F33);
  static const Color buttonOutlineBorder = Color(0xFF3A3A3F);

  // 分隔线颜色
  static const Color divider = Color(0xFF2A2A2E);

  // 交互颜色
  static const Color focus = Color(0xFF9E9EA2);
  static const Color hover = Color(0x339E9EA2);
  static const Color highlight = Color(0x1A9E9EA2);
  static const Color splash = Color(0x339E9EA2);
  static const Color overlay = Color(0x339E9EA2);

  // 复选框和单选框
  static const Color checkboxBorder = Color(0xFF5A5A5F);
  static const Color checkboxFill = Color(0xFF1C1C1F);
  static const Color checkboxSelected = Color(0xFF9E9EA2);
  static const Color checkboxCheck = Colors.black;

  // 开关
  static const Color switchThumb = Color(0xFF2E2E32);
  static const Color switchTrack = Color(0x332E2E32);
  static const Color switchThumbSelected = Color(0xFF9E9EA2);
  static const Color switchTrackSelected = Color(0x669E9EA2);
}
