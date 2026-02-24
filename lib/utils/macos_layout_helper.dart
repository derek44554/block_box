import 'package:flutter/material.dart';
import '../core/utils/helpers/platform_helper.dart';

/// macOS 布局辅助工具类
/// 提供 macOS 特定的间距、尺寸等常量
class MacOSLayoutHelper {
  MacOSLayoutHelper._();

  /// 根据平台返回水平内边距
  static double horizontalPadding(BuildContext context) {
    return PlatformHelper.isMacOS ? 48.0 : 24.0;
  }

  /// 根据平台返回垂直内边距
  static double verticalPadding(BuildContext context) {
    return PlatformHelper.isMacOS ? 32.0 : 20.0;
  }

  /// 根据平台返回圆角半径
  static double borderRadius(BuildContext context) {
    return PlatformHelper.isMacOS ? 10.0 : 14.0;
  }

  /// 根据平台返回更大的圆角半径
  static double largeBorderRadius(BuildContext context) {
    return PlatformHelper.isMacOS ? 12.0 : 16.0;
  }

  /// 根据平台返回按钮内边距
  static EdgeInsets buttonPadding(BuildContext context) {
    return PlatformHelper.isMacOS
        ? const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0)
        : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0);
  }

  /// 根据平台返回输入框内边距
  static EdgeInsets inputPadding(BuildContext context) {
    return PlatformHelper.isMacOS
        ? const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0)
        : const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0);
  }

  /// 根据平台返回卡片间距
  static double cardSpacing(BuildContext context) {
    return PlatformHelper.isMacOS ? 20.0 : 16.0;
  }

  /// 根据平台返回节间距
  static double sectionSpacing(BuildContext context) {
    return PlatformHelper.isMacOS ? 48.0 : 40.0;
  }

  /// 根据平台返回最大内容宽度（用于居中布局）
  static double? maxContentWidth(BuildContext context) {
    return PlatformHelper.isMacOS ? 1200.0 : null;
  }

  /// 根据平台返回字体大小
  static double fontSize(BuildContext context, {
    required double mobile,
    double? desktop,
  }) {
    if (PlatformHelper.isMacOS && desktop != null) {
      return desktop;
    }
    return mobile;
  }

  /// 根据平台返回图标大小
  static double iconSize(BuildContext context, {
    required double mobile,
    double? desktop,
  }) {
    if (PlatformHelper.isMacOS && desktop != null) {
      return desktop;
    }
    return mobile;
  }
}









