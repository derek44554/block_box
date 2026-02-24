import 'dart:io';

import 'package:flutter/foundation.dart';

/// 平台检测工具类
class PlatformHelper {
  const PlatformHelper._();

  /// 是否为 macOS 平台
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// 是否为 iOS 平台
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// 是否为 Android 平台
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// 是否为移动平台（iOS 或 Android）
  static bool get isMobile => isIOS || isAndroid;

  /// 是否为桌面平台（macOS、Windows、Linux）
  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// 根据平台返回不同的值
  static T platformValue<T>({
    required T macOS,
    T? iOS,
    T? android,
    T? desktop,
    T? mobile,
    T? defaultValue,
  }) {
    if (isMacOS) return macOS;
    if (isIOS && iOS != null) return iOS;
    if (isAndroid && android != null) return android;
    if (isDesktop && desktop != null) return desktop;
    if (isMobile && mobile != null) return mobile;
    return defaultValue ?? macOS;
  }
}
