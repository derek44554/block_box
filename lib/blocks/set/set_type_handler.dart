import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../common/block_registry.dart';
import '../common/block_type_ids.dart';
import 'pages/set_detail_page.dart';
import 'pages/set_edit_page.dart';
import 'widgets/collection_card.dart';

/// 集合类型处理器
///
/// 处理集合类型 Block 的详情页、编辑页和卡片组件。
class SetTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.set;

  @override
  Widget createDetailPage(BlockModel block) {
    return SetDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    return SetEditPage(block: block);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    return CollectionCard(block: block, onTap: onTap);
  }
}
