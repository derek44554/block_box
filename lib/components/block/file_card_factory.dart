import 'package:flutter/material.dart';
import '../../blocks/file/models/file_card_data.dart';
import '../../blocks/file/widgets/file_card_bank.dart';
import '../../blocks/file/widgets/image_file_card.dart';
import '../../core/models/block_model.dart';
import '../../utils/file_category.dart';

typedef FileCardBuilder = Widget Function(BlockModel block);

/// File 类型卡片的分发工厂，可根据文件扩展属性返回对应卡片。
class FileCardFactory {
  FileCardFactory._();

  static Widget build(BlockModel block) {
    final data = FileCardData.fromBlock(block);
    final category = resolveFileCategory(data.extension);
    if (category.isImage) {
      return ImageFileCard(block: block, cardData: data);
    }
    return FileCard(block: block, cardData: data);
  }
}

