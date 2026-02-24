import 'package:flutter/material.dart';
import '../../core/models/block_model.dart';
import '../common/block_registry.dart';
import '../common/block_type_ids.dart';
import 'pages/file_detail_page.dart';
import 'pages/file_edit_page.dart';
import 'widgets/file_card_bank.dart';
import 'models/file_card_data.dart';

/// 文件类型处理器
///
/// 处理文件类型 Block 的详情页、编辑页和卡片组件。
class FileTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.file;

  @override
  Widget createDetailPage(BlockModel block) {
    return FileDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    // 所有文件类型都支持编辑，图片类型使用图片模式
    final fileName = block.maybeString('fileName') ?? '';
    final extension = fileName.contains('.') 
        ? fileName.split('.').last.toLowerCase() 
        : '';
    
    final isImageFile = _isImageExtension(extension);
    return FileEditPage(block: block, isImageMode: isImageFile);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    final cardData = FileCardData.fromBlock(block);
    return FileCard(block: block, cardData: cardData);
  }

  /// 判断是否为图片扩展名
  bool _isImageExtension(String extension) {
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return imageExtensions.contains(extension);
  }
}
