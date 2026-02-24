import 'package:flutter/material.dart';

import '../../blocks/common/block_registry.dart';
import '../../blocks/document/widgets/document_card.dart';
import '../../core/models/block_model.dart';

typedef BlockCardBuilder = Widget Function(BlockModel block);

/// 统一的 Block 卡片构建工厂，根据 block 类型返回对应卡片。
///
/// 此工厂使用 BlockRegistry 来创建卡片，确保所有 Block 类型的卡片
/// 都通过统一的注册系统管理。
class BlockCardFactory {
  BlockCardFactory._();

  /// 根据 Block 类型返回对应卡片，未匹配到时使用默认处理。
  ///
  /// [block] 要显示的 Block 数据
  /// [fallback] 当未找到对应处理器时的后备构建器
  /// [onTap] 点击卡片时的回调
  ///
  /// 返回对应类型的卡片 Widget
  static Widget build(
    BlockModel block, {
    BlockCardBuilder? fallback,
    VoidCallback? onTap,
  }) {
    // 尝试使用 BlockRegistry 创建卡片
    final card = BlockRegistry.createCard(block, onTap: onTap);
    
    if (card != null) {
      return card;
    }

    // 如果 BlockRegistry 没有找到处理器，使用 fallback
    if (fallback != null) {
      return fallback(block);
    }

    // 最后的后备方案：使用 DocumentCard
    return DocumentCard(block: block);
  }
}
