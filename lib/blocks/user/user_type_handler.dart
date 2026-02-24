import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../common/block_registry.dart';
import '../common/block_type_ids.dart';
import 'pages/user_detail_page.dart';
import 'pages/user_edit_page.dart';
import 'widgets/user_card.dart';

/// 用户类型处理器
///
/// 处理用户类型 Block 的详情页、编辑页和卡片组件。
class UserTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.user;

  @override
  Widget createDetailPage(BlockModel block) {
    return UserDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    return UserEditPage(block: block);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    return UserCard(block: block, onTap: onTap);
  }
}
