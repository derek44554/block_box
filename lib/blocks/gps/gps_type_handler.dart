import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../common/block_registry.dart';
import '../common/block_type_ids.dart';
import 'pages/gps_detail_page.dart';
import 'pages/gps_edit_page.dart';
import 'widgets/gps_card.dart';

/// GPS 类型处理器
///
/// 处理 GPS 位置类型 Block 的详情页、编辑页和卡片组件。
class GpsTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.gps;

  @override
  Widget createDetailPage(BlockModel block) {
    return GpsDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    return GpsEditPage(block: block);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    return GpsCard(block: block, onTap: onTap);
  }
}
