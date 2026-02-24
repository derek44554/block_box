import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用配置常量
/// 
/// 定义应用级别的配置参数，包括：
/// - 应用名称和版本
/// - 主题配置
/// - 本地化配置
/// - 路由配置
class AppConfig {
  /// 应用名称
  static const String appName = 'BlockBox';
  
  /// 是否显示调试标识
  static const bool debugShowCheckedModeBanner = false;
  
  /// 默认语言
  static const Locale defaultLocale = Locale('zh', 'CN');
  
  /// 支持的语言列表
  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ];
  
  /// macOS 支持的屏幕方向
  static const List<DeviceOrientation> macOSOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  
  /// 移动端支持的屏幕方向
  static const List<DeviceOrientation> mobileOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];
}
