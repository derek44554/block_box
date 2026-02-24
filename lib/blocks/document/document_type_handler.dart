import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../common/block_registry.dart';
import '../common/block_type_ids.dart';
import 'pages/document_detail_page.dart';
import 'pages/document_edit_page.dart';
import 'widgets/document_card.dart';

/// 文档类型处理器
///
/// 处理文档类型 Block 的详情页、编辑页和卡片组件。
class DocumentTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.document;

  @override
  Widget createDetailPage(BlockModel block) {
    return DocumentDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    return DocumentEditPage(block: block);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    return DocumentCard(block: block, onTap: onTap);
  }
}
