import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../models/collect_models.dart';
import '../providers/collect_provider.dart';
import '../../aggregation/models/aggregation_models.dart';
import '../../aggregation/providers/aggregation_provider.dart';
import '../../photo/models/photo_models.dart';
import '../../photo/providers/photo_provider.dart';
import '../../music/models/music_models.dart';
import '../../music/providers/music_provider.dart';

/// 收藏、聚集、相册和音乐数据备份服务
///
/// 提供收藏、聚集、相册集合和音乐集合数据的统一导出和导入功能
/// 
/// 支持的数据类型：
/// - 收藏数据：标签、分组、条目
/// - 聚集数据：聚集项
/// - 相册数据：相册集合（包括相册标记）
/// - 音乐数据：音乐集合（包括播放列表标记）
class CollectBackupService {
  static const String _backupVersion = '1.0.0';
  static const String _backupFileExtension = 'json';
  static const String _defaultFileName = 'app_backup';

  /// 导出收藏、聚集、相册和音乐数据到用户选择的路径
  ///
  /// [collectProvider] 收藏数据提供者
  /// [aggregationProvider] 聚集数据提供者
  /// [photoProvider] 相册数据提供者
  /// [musicProvider] 音乐数据提供者
  /// [includeSelection] 是否包含当前选择状态
  /// 返回导出结果信息
  static Future<ExportResult> exportAllDataWithDialog(
    CollectProvider collectProvider,
    AggregationProvider aggregationProvider,
    PhotoProvider photoProvider,
    MusicProvider musicProvider, {
    bool includeSelection = false,
  }) async {
    try {
      // 1. 创建备份数据
      final backupData = _createBackupData(
        collectProvider,
        aggregationProvider,
        photoProvider,
        musicProvider,
        includeSelection,
      );
      
      // 2. 转换为 JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${_defaultFileName}_$timestamp.$_backupFileExtension';

      // 3. 让用户选择保存目录
      String? selectedDirectory;
      try {
        print('正在打开目录选择对话框...');
        selectedDirectory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '选择备份文件保存位置',
        );
        print('目录选择结果: $selectedDirectory');
      } catch (pickerError, stackTrace) {
        print('目录选择器错误: $pickerError');
        print('堆栈跟踪: $stackTrace');
        return ExportResult.error('无法打开目录选择对话框：$pickerError');
      }

      if (selectedDirectory == null) {
        print('用户取消了目录选择');
        return ExportResult.cancelled();
      }

      // 4. 确保目录路径有效
      if (selectedDirectory.isEmpty) {
        return ExportResult.error('目录路径无效：路径为空');
      }

      final outputFile = '$selectedDirectory/$fileName';
      print('准备写入文件: $outputFile');

      // 5. 写入文件
      try {
        final file = File(outputFile);
        print('开始写入文件，数据大小: ${jsonString.length} 字节');
        
        await file.writeAsString(jsonString, encoding: utf8);
        print('文件写入完成');
        
        // 6. 验证文件是否成功写入
        if (!await file.exists()) {
          return ExportResult.error('文件写入失败：文件未创建\n路径: $outputFile');
        }
        
        final fileSize = await file.length();
        print('文件大小: $fileSize 字节');
        
        if (fileSize == 0) {
          return ExportResult.error('文件写入失败：文件为空\n路径: $outputFile');
        }

        print('导出成功: $outputFile');
        return ExportResult.success(outputFile);
      } catch (writeError, stackTrace) {
        print('文件写入错误: $writeError');
        print('堆栈跟踪: $stackTrace');
        return ExportResult.error('文件写入失败：$writeError\n路径: $outputFile');
      }
    } catch (error, stackTrace) {
      print('导出过程错误: $error');
      print('堆栈跟踪: $stackTrace');
      return ExportResult.error('导出失败：$error');
    }
  }

  /// 导入收藏、聚集、相册和音乐数据
  ///
  /// [collectProvider] 收藏数据提供者
  /// [aggregationProvider] 聚集数据提供者
  /// [photoProvider] 相册数据提供者
  /// [musicProvider] 音乐数据提供者
  /// [mergeMode] 导入模式：true为合并，false为覆盖
  /// 返回导入结果信息
  static Future<ImportResult> importAllData(
    CollectProvider collectProvider,
    AggregationProvider aggregationProvider,
    PhotoProvider photoProvider,
    MusicProvider musicProvider, {
    bool mergeMode = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [_backupFileExtension],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      final file = result.files.first;
      if (file.path == null) {
        return ImportResult.error('无法读取选择的文件');
      }

      final fileContent = await File(file.path!).readAsString(encoding: utf8);
      final backupData = jsonDecode(fileContent) as Map<String, dynamic>;

      return await _importBackupData(
        collectProvider,
        aggregationProvider,
        photoProvider,
        musicProvider,
        backupData,
        mergeMode,
      );
    } catch (error) {
      return ImportResult.error('导入失败：${error.toString()}');
    }
  }

  /// 从文件路径导入收藏、聚集、相册和音乐数据
  ///
  /// [collectProvider] 收藏数据提供者
  /// [aggregationProvider] 聚集数据提供者
  /// [photoProvider] 相册数据提供者
  /// [musicProvider] 音乐数据提供者
  /// [filePath] 备份文件路径
  /// [mergeMode] 导入模式：true为合并，false为覆盖
  static Future<ImportResult> importFromFile(
    CollectProvider collectProvider,
    AggregationProvider aggregationProvider,
    PhotoProvider photoProvider,
    MusicProvider musicProvider,
    String filePath, {
    bool mergeMode = true,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult.error('文件不存在');
      }

      final fileContent = await file.readAsString(encoding: utf8);
      final backupData = jsonDecode(fileContent) as Map<String, dynamic>;

      return await _importBackupData(
        collectProvider,
        aggregationProvider,
        photoProvider,
        musicProvider,
        backupData,
        mergeMode,
      );
    } catch (error) {
      return ImportResult.error('导入失败：${error.toString()}');
    }
  }

  /// 创建备份数据
  static Map<String, dynamic> _createBackupData(
    CollectProvider collectProvider,
    AggregationProvider aggregationProvider,
    PhotoProvider photoProvider,
    MusicProvider musicProvider,
    bool includeSelection,
  ) {
    final data = <String, dynamic>{
      'version': _backupVersion,
      'timestamp': DateTime.now().toIso8601String(),
      // 收藏数据
      'collect': {
        'tags': collectProvider.tags.map((tag) => tag.toJson()).toList(),
        'entries': collectProvider.entries
            .map((entry) => entry.toJson())
            .toList(),
        'gridLayoutBids': collectProvider.gridLayoutBids.toList(),
      },
      // 聚集数据
      'aggregation': {
        'items': aggregationProvider.items
            .map((item) => item.toJson())
            .toList(),
        'gridLayoutItemIds': aggregationProvider.gridLayoutItemIds.toList(),
      },
      // 相册集合数据
      'photo': {
        'collections': photoProvider.collections
            .map((collection) => collection.toJson())
            .toList(),
      },
      // 音乐集合数据
      'music': {
        'collections': musicProvider.collections
            .map((collection) => collection.toJson())
            .toList(),
      },
    };

    if (includeSelection) {
      // 收藏选择状态
      if (collectProvider.persistedSelection != null) {
        final selection = collectProvider.persistedSelection!;
        data['collect']['selection'] = {
          'groupId': selection.groupId,
          'itemBid': selection.itemBid,
        };
      }

      // 聚集选择状态
      if (aggregationProvider.selectedItemId != null) {
        data['aggregation']['selectedItemId'] =
            aggregationProvider.selectedItemId;
      }
    }

    return data;
  }

  /// 导入备份数据
  static Future<ImportResult> _importBackupData(
    CollectProvider collectProvider,
    AggregationProvider aggregationProvider,
    PhotoProvider photoProvider,
    MusicProvider musicProvider,
    Map<String, dynamic> backupData,
    bool mergeMode,
  ) async {
    try {
      // 验证备份数据格式
      final validationResult = _validateBackupData(backupData);
      if (!validationResult.isValid) {
        return ImportResult.error(validationResult.error!);
      }

      // 统计信息
      var importedTags = 0;
      var importedEntries = 0;
      var importedItems = 0;
      var importedAggregationItems = 0;
      var importedPhotoCollections = 0;
      var importedMusicCollections = 0;

      // 处理收藏数据
      final collectData = backupData['collect'] as Map<String, dynamic>?;
      Map<String, dynamic>? actualCollectData = collectData;

      // 兼容旧版本格式
      if (collectData == null &&
          backupData.containsKey('tags') &&
          backupData.containsKey('entries')) {
        actualCollectData = {
          'tags': backupData['tags'],
          'entries': backupData['entries'],
          'gridLayoutBids': backupData['gridLayoutBids'] ?? [],
        };
        if (backupData.containsKey('selection')) {
          actualCollectData['selection'] = backupData['selection'];
        }
      }

      if (actualCollectData != null) {
        final tags =
            (actualCollectData['tags'] as List<dynamic>?)
                ?.map(
                  (item) => CollectTag.fromJson(item as Map<String, dynamic>),
                )
                .toList() ??
            <CollectTag>[];

        final entries =
            (actualCollectData['entries'] as List<dynamic>?)
                ?.map(
                  (item) => CollectEntry.fromJson(item as Map<String, dynamic>),
                )
                .toList() ??
            <CollectEntry>[];

        final gridLayoutBids =
            (actualCollectData['gridLayoutBids'] as List<dynamic>?)
                ?.map((item) => item.toString())
                .toSet() ??
            <String>{};

        if (mergeMode) {
          // 合并模式：添加不存在的数据
          final existingTagNames = collectProvider.tags
              .map((tag) => tag.name)
              .toSet();
          for (final tag in tags) {
            if (!existingTagNames.contains(tag.name)) {
              await collectProvider.addTag(tag.name);
              importedTags++;
            }
          }

          final existingEntryTitles = collectProvider.entries
              .map((entry) => entry.title)
              .toSet();
          for (final entry in entries) {
            if (!existingEntryTitles.contains(entry.title)) {
              await collectProvider.addEntry(entry.title);
              importedEntries++;

              // 添加条目中的项目
              final newEntry = collectProvider.entries.lastWhere(
                (e) => e.title == entry.title,
              );
              for (final item in entry.items) {
                await collectProvider.addItem(newEntry.id, item);
                importedItems++;
              }
            }
          }

          // 合并网格布局设置
          for (final bid in gridLayoutBids) {
            if (!collectProvider.gridLayoutBids.contains(bid)) {
              await collectProvider.setGridLayoutForBid(bid, true);
            }
          }
        } else {
          // 覆盖模式：清空现有数据后导入
          // 注意：这里需要扩展 CollectProvider 来支持清空所有数据
          // 暂时先实现合并模式，覆盖模式可以后续添加
          return ImportResult.error('覆盖模式暂未实现，请使用合并模式');
        }
      }

      // 处理聚集数据
      final aggregationData =
          backupData['aggregation'] as Map<String, dynamic>?;
      if (aggregationData != null) {
        final items =
            (aggregationData['items'] as List<dynamic>?)
                ?.map(
                  (item) =>
                      AggregationItem.fromJson(item as Map<String, dynamic>),
                )
                .toList() ??
            <AggregationItem>[];

        final gridLayoutItemIds =
            (aggregationData['gridLayoutItemIds'] as List<dynamic>?)
                ?.map((item) => item.toString())
                .toSet() ??
            <String>{};

        if (mergeMode) {
          // 合并模式：添加不存在的数据
          final existingItemTitles = aggregationProvider.items
              .map((item) => item.title)
              .toSet();
          for (final item in items) {
            if (!existingItemTitles.contains(item.title)) {
              await aggregationProvider.addItem(item.title, item.model);
              importedAggregationItems++;

              // 添加标签
              final newItem = aggregationProvider.items.lastWhere(
                (i) => i.title == item.title,
              );
              for (final tag in item.tags) {
                await aggregationProvider.addTagToItem(newItem.id, tag);
              }
            }
          }

          // 合并网格布局设置
          for (final itemId in gridLayoutItemIds) {
            if (!aggregationProvider.gridLayoutItemIds.contains(itemId)) {
              await aggregationProvider.setGridLayoutForItem(itemId, true);
            }
          }
        }
      }

      // 处理相册集合数据
      final photoData = backupData['photo'] as Map<String, dynamic>?;
      if (photoData != null) {
        final collections =
            (photoData['collections'] as List<dynamic>?)
                ?.map(
                  (item) =>
                      PhotoCollection.fromJson(item as Map<String, dynamic>),
                )
                .toList() ??
            <PhotoCollection>[];

        if (mergeMode) {
          // 合并模式：添加不存在的集合
          final existingBids = photoProvider.collections
              .map((c) => c.bid)
              .toSet();
          for (final collection in collections) {
            if (!existingBids.contains(collection.bid)) {
              await photoProvider.addCollection(collection);
              importedPhotoCollections++;
            }
          }
        }
      }

      // 处理音乐集合数据
      final musicData = backupData['music'] as Map<String, dynamic>?;
      if (musicData != null) {
        final collections =
            (musicData['collections'] as List<dynamic>?)
                ?.map(
                  (item) =>
                      MusicCollection.fromJson(item as Map<String, dynamic>),
                )
                .toList() ??
            <MusicCollection>[];

        if (mergeMode) {
          // 合并模式：添加不存在的集合
          final existingBids = musicProvider.collections
              .map((c) => c.bid)
              .toSet();
          for (final collection in collections) {
            if (!existingBids.contains(collection.bid)) {
              await musicProvider.addCollection(collection);
              importedMusicCollections++;
            }
          }
        }
      }

      return ImportResult.success(
        importedTags: importedTags,
        importedEntries: importedEntries,
        importedItems: importedItems,
        importedAggregationItems: importedAggregationItems,
        importedPhotoCollections: importedPhotoCollections,
        importedMusicCollections: importedMusicCollections,
      );
    } catch (error) {
      return ImportResult.error('处理备份数据失败：${error.toString()}');
    }
  }

  /// 验证备份数据格式
  static ValidationResult _validateBackupData(Map<String, dynamic> data) {
    try {
      // 检查版本
      final version = data['version'] as String?;
      if (version == null) {
        return ValidationResult.invalid('备份文件缺少版本信息');
      }

      // 检查是否有收藏或聚集数据
      final hasCollectData = data.containsKey('collect');
      final hasAggregationData = data.containsKey('aggregation');

      if (!hasCollectData && !hasAggregationData) {
        // 兼容旧版本格式
        if (data.containsKey('tags') && data.containsKey('entries')) {
          return ValidationResult.valid();
        }
        return ValidationResult.invalid('备份文件格式不正确');
      }

      // 检查收藏数据格式
      if (hasCollectData) {
        final collectData = data['collect'] as Map<String, dynamic>?;
        if (collectData != null) {
          if (collectData['tags'] is! List || collectData['entries'] is! List) {
            return ValidationResult.invalid('收藏数据格式不正确');
          }
        }
      }

      // 检查聚集数据格式
      if (hasAggregationData) {
        final aggregationData = data['aggregation'] as Map<String, dynamic>?;
        if (aggregationData != null) {
          if (aggregationData['items'] is! List) {
            return ValidationResult.invalid('聚集数据格式不正确');
          }
        }
      }

      return ValidationResult.valid();
    } catch (error) {
      return ValidationResult.invalid('备份文件格式验证失败：${error.toString()}');
    }
  }
}

/// 导入结果
class ImportResult {
  const ImportResult._({
    required this.success,
    this.error,
    this.importedTags = 0,
    this.importedEntries = 0,
    this.importedItems = 0,
    this.importedAggregationItems = 0,
    this.importedPhotoCollections = 0,
    this.importedMusicCollections = 0,
    this.cancelled = false,
  });

  factory ImportResult.success({
    int importedTags = 0,
    int importedEntries = 0,
    int importedItems = 0,
    int importedAggregationItems = 0,
    int importedPhotoCollections = 0,
    int importedMusicCollections = 0,
  }) {
    return ImportResult._(
      success: true,
      importedTags: importedTags,
      importedEntries: importedEntries,
      importedItems: importedItems,
      importedAggregationItems: importedAggregationItems,
      importedPhotoCollections: importedPhotoCollections,
      importedMusicCollections: importedMusicCollections,
    );
  }

  factory ImportResult.error(String error) {
    return ImportResult._(success: false, error: error);
  }

  factory ImportResult.cancelled() {
    return ImportResult._(success: false, cancelled: true);
  }

  final bool success;
  final String? error;
  final int importedTags;
  final int importedEntries;
  final int importedItems;
  final int importedAggregationItems;
  final int importedPhotoCollections;
  final int importedMusicCollections;
  final bool cancelled;

  bool get hasImportedData =>
      importedTags > 0 ||
      importedEntries > 0 ||
      importedItems > 0 ||
      importedAggregationItems > 0 ||
      importedPhotoCollections > 0 ||
      importedMusicCollections > 0;
}

/// 导出结果
class ExportResult {
  const ExportResult._({
    required this.success,
    this.error,
    this.filePath,
    this.cancelled = false,
  });

  factory ExportResult.success(String filePath) {
    return ExportResult._(success: true, filePath: filePath);
  }

  factory ExportResult.error(String error) {
    return ExportResult._(success: false, error: error);
  }

  factory ExportResult.cancelled() {
    return ExportResult._(success: false, cancelled: true);
  }

  final bool success;
  final String? error;
  final String? filePath;
  final bool cancelled;
}

/// 验证结果
class ValidationResult {
  const ValidationResult._({required this.isValid, this.error});

  factory ValidationResult.valid() => const ValidationResult._(isValid: true);
  factory ValidationResult.invalid(String error) =>
      ValidationResult._(isValid: false, error: error);

  final bool isValid;
  final String? error;
}
