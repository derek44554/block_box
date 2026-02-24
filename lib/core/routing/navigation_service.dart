import 'package:flutter/material.dart';

import '../models/block_model.dart';
import 'app_router.dart';

/// 导航服务，提供统一的导航方法
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = 
      GlobalKey<NavigatorState>();
  
  /// 导航到命名路由
  static Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }
  
  /// 替换当前路由
  static Future<T?> replaceTo<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed<T, Object?>(
      routeName,
      arguments: arguments,
    );
  }
  
  /// 返回
  static void goBack<T>([T? result]) {
    navigatorKey.currentState!.pop(result);
  }
  
  /// 导航到 Block 详情页
  static Future<T?> navigateToBlockDetail<T>(BlockModel block) {
    return AppRouter.openBlockDetailPage<T>(
      navigatorKey.currentContext!,
      block,
    );
  }
  
  /// 导航到 Block 编辑页
  static Future<BlockModel?> navigateToBlockEdit(BlockModel block) {
    return AppRouter.openBlockEditPage(
      navigatorKey.currentContext!,
      block,
    );
  }
}
