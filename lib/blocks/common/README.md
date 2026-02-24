# Blocks Common

此目录包含 Block 类型系统的核心组件和通用功能。

## 文件说明

### block_registry.dart
Block 类型注册表，提供统一的接口来管理和访问不同类型的 Block 处理器。

**主要功能：**
- 注册 Block 类型处理器
- 根据类型 ID 获取对应的处理器
- 统一的详情页、编辑页打开接口
- 统一的卡片组件创建接口

**使用示例：**
```dart
// 注册处理器
BlockRegistry.register(DocumentTypeHandler());

// 打开详情页
await BlockRegistry.openDetailPage(context, block);

// 打开编辑页
final updatedBlock = await BlockRegistry.openEditPage(context, block);

// 创建卡片
final card = BlockRegistry.createCard(block, onTap: () {});
```

### block_type_ids.dart
定义所有 Block 类型的 ID 常量。

**使用示例：**
```dart
if (block.maybeString('model') == BlockTypeIds.document) {
  // 处理文档类型
}
```

### block_detail_page.dart
通用的 Block 详情页面，用于显示未注册特定处理器的 Block 类型。

## 添加新的 Block 类型

要添加新的 Block 类型，需要：

1. 在 `block_type_ids.dart` 中添加类型 ID 常量
2. 创建新的类型目录（如 `lib/blocks/my_type/`）
3. 实现 `BlockTypeHandler` 接口
4. 在应用启动时注册处理器

示例：
```dart
class MyTypeHandler implements BlockTypeHandler {
  @override
  String get typeId => BlockTypeIds.myType;

  @override
  Widget createDetailPage(BlockModel block) {
    return MyTypeDetailPage(block: block);
  }

  @override
  Widget? createEditPage(BlockModel block) {
    return MyTypeEditPage(block: block);
  }

  @override
  Widget createCard(BlockModel block, {VoidCallback? onTap}) {
    return MyTypeCard(block: block, onTap: onTap);
  }
}

// 在应用启动时注册
BlockRegistry.register(MyTypeHandler());
```
