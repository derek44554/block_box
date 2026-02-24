import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/routing/app_router.dart';
import '../core/routing/route_names.dart';
import '../core/theme/app_theme.dart';
import 'app_config.dart';
import 'dependency_injection.dart';

/// BlockBox 主应用组件
/// 
/// 封装了 MaterialApp 的配置，包括：
/// - 主题配置
/// - 路由配置
/// - 本地化配置
/// - Provider 配置
class BlockApp extends StatelessWidget {
  const BlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: DependencyInjection.getProviders(),
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: AppConfig.debugShowCheckedModeBanner,
        theme: AppTheme.dark(),
        locale: AppConfig.defaultLocale,
        supportedLocales: AppConfig.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: RouteNames.home,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
