import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'app/dependency_injection.dart';
import 'core/utils/helpers/platform_helper.dart';

/// BlockBox 应用入口
/// 
/// 负责：
/// 1. 初始化 Flutter 绑定
/// 2. 设置依赖注入
/// 3. 配置屏幕方向
/// 4. 配置系统 UI 样式
/// 5. 启动应用
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置依赖注入
  DependencyInjection.setupDependencies();
  
  // 配置屏幕方向
  await _configureOrientations();
  
  // 配置系统 UI 样式
  _configureSystemUI();
  
  runApp(const BlockApp());
}

/// 配置屏幕方向
/// 
/// macOS 允许所有方向，移动端限制为竖屏
Future<void> _configureOrientations() async {
  if (PlatformHelper.isMacOS) {
    await SystemChrome.setPreferredOrientations(
      AppConfig.macOSOrientations,
    );
  } else {
    await SystemChrome.setPreferredOrientations(
      AppConfig.mobileOrientations,
    );
  }
}

/// 配置系统 UI 样式
/// 
/// macOS 不需要设置状态栏样式
void _configureSystemUI() {
  if (!PlatformHelper.isMacOS) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }
}


