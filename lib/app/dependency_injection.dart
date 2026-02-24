import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../blocks/common/block_registry.dart';
import '../blocks/document/document_type_handler.dart';
import '../blocks/article/article_type_handler.dart';
import '../blocks/set/set_type_handler.dart';
import '../blocks/file/file_type_handler.dart';
import '../blocks/service/service_type_handler.dart';
import '../blocks/user/user_type_handler.dart';
import '../blocks/record/record_type_handler.dart';
import '../blocks/gps/gps_type_handler.dart';
import '../blocks/creed/creed_type_handler.dart';
import '../features/aggregation/providers/aggregation_provider.dart';
import '../state/connection_provider.dart';
import '../state/block_provider.dart';
import '../features/collect/providers/collect_provider.dart';
import '../features/photo/providers/photo_provider.dart';
import '../features/music/providers/music_provider.dart';

/// 依赖注入配置
/// 
/// 负责初始化应用的所有依赖，包括：
/// - Block 类型处理器注册
/// - Provider 配置
/// - 服务初始化
class DependencyInjection {
  /// 设置所有依赖
  /// 
  /// 应该在应用启动时调用一次
  static void setupDependencies() {
    _registerBlockTypeHandlers();
  }
  
  /// 注册所有 Block 类型处理器
  /// 
  /// 将各种 Block 类型的处理器注册到 BlockRegistry
  /// 使得系统能够根据 Block 类型动态创建对应的页面和组件
  static void _registerBlockTypeHandlers() {
    BlockRegistry.register(DocumentTypeHandler());
    BlockRegistry.register(ArticleTypeHandler());
    BlockRegistry.register(SetTypeHandler());
    BlockRegistry.register(FileTypeHandler());
    BlockRegistry.register(ServiceTypeHandler());
    BlockRegistry.register(UserTypeHandler());
    BlockRegistry.register(RecordTypeHandler());
    BlockRegistry.register(GpsTypeHandler());
    BlockRegistry.register(CreedTypeHandler());
  }
  
  /// 获取所有 Provider 配置
  /// 
  /// 返回应用需要的所有 Provider 列表
  /// 用于 MultiProvider 的 providers 参数
  static List<SingleChildWidget> getProviders() {
    return [
      ChangeNotifierProvider(create: (_) => ConnectionProvider()),
      ChangeNotifierProvider(create: (_) => BlockProvider()),
      ChangeNotifierProvider(create: (_) => AggregationProvider()),
      ChangeNotifierProvider(create: (_) => CollectProvider()),
      ChangeNotifierProvider(create: (_) => PhotoProvider()),
      ChangeNotifierProvider(create: (_) => MusicProvider()),
    ];
  }
}
