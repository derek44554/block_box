import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';

/// Block 类型处理器接口
///
/// 每个 Block 类型都应该实现此接口，提供该类型的详情页、编辑页和卡片组件。
abstract class BlockTypeHandler {
  /// Block 类型 ID
  ///
  /// 对应 BlockModel 中的 'model' 字段值
  String get typeId;

  /// 创建详情页面
  ///
  /// [block] 要显示的 Block 数据
  /// 返回该类型的详情页面 Widget
  Widget createDetailPage(BlockModel block);

  /// 创建编辑页面（可选）
  ///
  /// [block] 要编辑的 Block 数据
  /// 返回该类型的编辑页面 Widget，如果不支持编辑则返回 null
  Widget? createEditPage(BlockModel block);

  /// 创建卡片组件
  ///
  /// [block] 要显示的 Block 数据
  /// [onTap] 点击卡片时的回调
  /// 返回该类型的卡片组件 Widget
  Widget createCard(BlockModel block, {VoidCallback? onTap});
}

/// Block 类型注册表
///
/// 用于注册和管理所有 Block 类型的处理器。
/// 提供统一的接口来打开详情页、编辑页和创建卡片。
class BlockRegistry {
  BlockRegistry._();

  static final Map<String, BlockTypeHandler> _handlers = {};

  /// 注册 Block 类型处理器
  ///
  /// [handler] 要注册的处理器
  static void register(BlockTypeHandler handler) {
    _handlers[handler.typeId] = handler;
  }

  /// 批量注册 Block 类型处理器
  ///
  /// [handlers] 要注册的处理器列表
  static void registerAll(List<BlockTypeHandler> handlers) {
    for (final handler in handlers) {
      register(handler);
    }
  }

  /// 获取处理器
  ///
  /// [typeId] Block 类型 ID
  /// 返回对应的处理器，如果未注册则返回 null
  static BlockTypeHandler? getHandler(String typeId) {
    return _handlers[typeId];
  }

  /// 检查类型是否已注册
  ///
  /// [typeId] Block 类型 ID
  /// 返回 true 如果该类型已注册
  static bool isRegistered(String typeId) {
    return _handlers.containsKey(typeId);
  }

  /// 获取所有已注册的类型 ID
  ///
  /// 返回所有已注册的 Block 类型 ID 列表
  static List<String> getRegisteredTypeIds() {
    return _handlers.keys.toList();
  }

  /// 清空所有注册的处理器
  ///
  /// 主要用于测试
  static void clear() {
    _handlers.clear();
  }

  /// 打开 Block 详情页面
  ///
  /// [context] BuildContext
  /// [block] 要显示的 Block 数据
  /// [replace] 是否替换当前页面
  /// 返回 Future，可以获取页面返回的结果
  static Future<T?> openDetailPage<T>(
    BuildContext context,
    BlockModel block, {
    bool replace = false,
  }) {
    final typeId = block.maybeString('model') ?? '';
    final handler = getHandler(typeId);

    Widget page;
    if (handler != null) {
      page = handler.createDetailPage(block);
    } else {
      // 使用通用详情页作为后备
      // 注意：这里需要导入 BlockDetailPage，但为了避免循环依赖，
      // 我们将在后续步骤中处理
      throw UnimplementedError(
        'No handler registered for type: $typeId. '
        'Please register a handler or use BlockDetailPage directly.',
      );
    }

    final route = MaterialPageRoute<T>(builder: (_) => page);

    if (replace) {
      return Navigator.of(context).pushReplacement<T, Object?>(route);
    } else {
      return Navigator.of(context).push<T>(route);
    }
  }

  /// 打开 Block 编辑页面
  ///
  /// [context] BuildContext
  /// [block] 要编辑的 Block 数据
  /// 返回 Future<BlockModel?>，如果编辑成功则返回更新后的 Block
  static Future<BlockModel?> openEditPage(
    BuildContext context,
    BlockModel block,
  ) {
    final typeId = block.maybeString('model') ?? '';
    final handler = getHandler(typeId);

    if (handler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未找到类型 $typeId 的处理器')),
      );
      return Future.value(null);
    }

    final editPage = handler.createEditPage(block);

    if (editPage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂不支持此类型的块编辑')),
      );
      return Future.value(null);
    }

    return Navigator.of(context).push<BlockModel>(
      MaterialPageRoute(builder: (_) => editPage),
    );
  }

  /// 创建 Block 卡片组件
  ///
  /// [block] 要显示的 Block 数据
  /// [onTap] 点击卡片时的回调
  /// 返回卡片 Widget，如果未注册处理器则返回 null
  static Widget? createCard(BlockModel block, {VoidCallback? onTap}) {
    final typeId = block.maybeString('model') ?? '';
    final handler = getHandler(typeId);

    if (handler == null) {
      return null;
    }

    return handler.createCard(block, onTap: onTap);
  }
}
