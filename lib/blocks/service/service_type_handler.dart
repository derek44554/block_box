import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../common/block_registry.dart';
import '../common/block_type_ids.dart';
import 'pages/service_detail_page.dart';
import 'pages/service_edit_page.dart';
import 'widgets/service_card.dart';

/// 服务类型处理器
///
/// 处理服务类型 Block 的详情页、编辑页和卡片组件。
class ServiceTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.service;

  @override
  Widget createDetailPage(BlockModel block) {
    return ServiceDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    return ServiceEditPage(block: block);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    return ServiceCard(block: block, onTap: onTap);
  }
}
