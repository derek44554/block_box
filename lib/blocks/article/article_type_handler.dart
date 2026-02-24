import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../common/block_registry.dart';
import '../common/block_type_ids.dart';
import 'pages/article_detail_page.dart';
import 'pages/article_edit_page.dart';
import 'widgets/article_card.dart';

/// 文章类型处理器
///
/// 处理文章类型 Block 的详情页和卡片组件。
class ArticleTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.article;

  @override
  Widget createDetailPage(BlockModel block) {
    return ArticleDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    return ArticleEditPage(block: block);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    return ArticleCard(block: block, onTap: onTap);
  }
}
