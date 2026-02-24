import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../common/block_registry.dart';
import '../common/block_type_ids.dart';
import 'pages/creed_detail_page.dart';
import 'pages/creed_edit_page.dart';
import 'widgets/creed_card.dart';

/// 信条类型处理器
///
/// 处理信条类型 Block 的详情页、编辑页和卡片组件。
class CreedTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.creed;

  @override
  Widget createDetailPage(BlockModel block) {
    return CreedDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    return CreedEditPage(block: block);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    return CreedCard(block: block, onTap: onTap);
  }
}