import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../../blocks/common/block_registry.dart';
import '../../blocks/common/block_detail_page.dart';
import '../../blocks/common/block_type_ids.dart';
import '../../blocks/file/models/file_card_data.dart';
import '../../blocks/file/pages/image_detail_page.dart';
import '../../blocks/file/utils/file_category.dart';
import '../../blocks/file/pages/video_detail_page.dart';
import '../../blocks/file/pages/file_detail_page.dart';
import '../../features/aggregation/pages/aggregation_page.dart';
import '../../features/ai/pages/ai_page.dart';
import '../../features/collect/pages/collect_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/home/pages/mac_home_page.dart';
import '../../features/link/pages/link_page.dart';
import '../../features/music/pages/music_page.dart';
import '../../features/photo/pages/photo_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/tag/pages/tag_page.dart';
import '../../features/trace/pages/trace_page.dart';
import '../storage/cache/image_cache.dart';
import '../utils/helpers/platform_helper.dart';
import 'route_names.dart';

typedef RouteWidgetBuilder =
    Widget Function(BuildContext context, RouteSettings settings);

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(
        builder: (context) => builder(context, settings),
        settings: settings,
      );
    }
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(child: Text('No route defined for ${settings.name}')),
      ),
      settings: settings,
    );
  }

  static final Map<String, RouteWidgetBuilder> _routes = {
    RouteNames.home: (context, settings) => HomePage(),
    RouteNames.aggregation: (context, settings) => const AggregationPage(),
    RouteNames.collect: (context, settings) => CollectPage(),
    RouteNames.photo: (context, settings) => PhotoPage(),
    RouteNames.music: (context, settings) => const MusicPage(),
    RouteNames.ai: (context, settings) => AIPage(),
    RouteNames.trace: (context, settings) => const TracePage(),
    RouteNames.settings: (context, settings) => const SettingsPage(),
    RouteNames.tag: (context, settings) {
      final tag = settings.arguments as String? ?? '';
      return TagPage(tag: tag);
    },
    RouteNames.link: (context, settings) {
      final args = settings.arguments as Map<String, dynamic>? ?? {};
      final bid = args['bid'] as String?;
      final initialIndex = args['initialIndex'] as int? ?? 0;
      return LinkPage(bid: bid, initialIndex: initialIndex);
    },
  };

  /// 根据 Block 类型打开对应的编辑页面。
  ///
  /// 此方法使用 BlockRegistry 来查找并打开对应类型的编辑页面。
  /// 如果编辑成功，将返回更新后的 [BlockModel]。
  /// 如果找不到匹配的编辑页面，则会显示提示信息并返回 null。
  static Future<BlockModel?> openBlockEditPage(
    BuildContext context,
    BlockModel block,
  ) {
    return BlockRegistry.openEditPage(context, block);
  }

  /// 根据 Block 类型打开对应的详情页面。
  ///
  /// 此方法使用 BlockRegistry 来查找并打开对应类型的详情页面。
  /// 对于文件类型，支持特殊的初始化参数（如图片字节数据）。
  /// 在 macOS 平台上，会尝试使用嵌套的 Navigator。
  static Future<T?> openBlockDetailPage<T extends Object?>(
    BuildContext context,
    BlockModel block, {
    bool replace = false,
    Uint8List? initialImageBytes,
    ImageVariant? initialImageVariant,
    NavigatorState? navigator,
  }) {
    final model = block.maybeString('model');
    Widget page;

    // 文件类型需要特殊处理，因为它有多个子类型（图片、视频、普通文件）
    // 并且图片类型支持从字节数据初始化
    if (model == BlockTypeIds.file) {
      final fileData = FileCardData.fromBlock(block);
      final extension = fileData.extension.toLowerCase();
      if (resolveFileCategory(fileData.extension).isImage) {
        if (initialImageBytes != null && initialImageBytes.isNotEmpty) {
          page = ImageDetailPage.fromBytes(
            block: block,
            bytes: initialImageBytes,
            variant: initialImageVariant ?? ImageVariant.medium,
          );
        } else {
          page = ImageDetailPage(block: block);
        }
      } else if (extension == 'mp4' || extension == 'flv') {
        page = VideoDetailPage(block: block);
      } else {
        page = FileDetailPage(block: block);
      }
    } else {
      // 对于其他类型，使用 BlockRegistry
      final typeId = model ?? '';
      final handler = BlockRegistry.getHandler(typeId);

      if (handler != null) {
        page = handler.createDetailPage(block);
      } else {
        // 使用通用详情页作为后备
        page = BlockDetailPage(block: block);
      }
    }

    final route = MaterialPageRoute<T>(builder: (_) => page);

    // 在 macOS 下，尝试使用嵌套 Navigator
    NavigatorState? targetNavigator = navigator;
    if (targetNavigator == null && PlatformHelper.isMacOS) {
      final nestedNavigator = MacContentNavigatorProvider.of(context);
      if (nestedNavigator != null) {
        targetNavigator = nestedNavigator;
      }
    }
    targetNavigator ??= Navigator.of(context);

    if (replace) {
      return targetNavigator.pushReplacement<T, Object?>(route);
    } else {
      return targetNavigator.push<T>(route);
    }
  }
}
