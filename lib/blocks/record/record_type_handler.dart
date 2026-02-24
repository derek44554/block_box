import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../common/block_registry.dart';
import '../common/block_type_ids.dart';
import 'pages/record_detail_page.dart';
import 'pages/record_edit_page.dart';
import 'widgets/record_card.dart';

/// 档案类型处理器
///
/// 处理档案类型 Block 的详情页、编辑页和卡片组件。
class RecordTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.record;

  @override
  Widget createDetailPage(BlockModel block) {
    return RecordDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    return RecordEditPage(block: block);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    return RecordCard(block: block, onTap: onTap);
  }
}
