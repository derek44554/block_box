# Block 组件

本目录包含跨多个 Block 类型使用的通用组件和工具。

## 目录结构

```
block/
├── widgets/                      # Block 通用 UI 组件
│   ├── block_header.dart        # Block 头部组件
│   ├── block_meta_column.dart   # Block 元数据列
│   ├── block_meta_tile.dart     # Block 元数据瓦片
│   ├── block_permission_card.dart  # Block 权限卡片
│   ├── block_quick_actions.dart # Block 快捷操作
│   └── block_section_header.dart   # Block 区块标题
├── block_card_factory.dart      # Block 卡片工厂
├── block_grid_layout.dart       # Block 网格布局
├── file_card_factory.dart       # 文件卡片工厂
└── raw_data_page.dart           # 原始数据查看页
```

## 组件说明

### Block 卡片工厂

**BlockCardFactory** 根据 Block 类型自动创建对应的卡片组件。

```dart
// 使用 BlockRegistry 创建卡片
final card = BlockCardFactory.createCard(blockModel);
```

### Block 网格布局

**BlockGridLayout** 提供 Block 列表的网格展示布局。

```dart
BlockGridLayout(
  blocks: blockList,
  onBlockTap: (block) {
    // 处理点击
  },
)
```

### Block 通用 UI 组件

这些组件用于构建 Block 详情页的标准 UI：

- **BlockHeader**：显示 Block 的标题、图标和基本信息
- **BlockMetaColumn**：以列的形式显示 Block 元数据
- **BlockMetaTile**：以瓦片形式显示单个元数据项
- **BlockPermissionCard**：显示和编辑 Block 的权限设置
- **BlockQuickActions**：提供快捷操作按钮（编辑、删除、分享等）
- **BlockSectionHeader**：区块内的小节标题

### 原始数据查看页

**RawDataPage** 允许查看和编辑 Block 的原始 JSON 数据。

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => RawDataPage(block: blockModel),
  ),
);
```

## 使用规范

### 导入路径

使用绝对路径导入：

```dart
import 'package:block_app/components/block/block_card_factory.dart';
import 'package:block_app/components/block/widgets/block_header.dart';
```

### 何时使用这些组件

- **跨 Block 类型使用**：当组件需要在多个 Block 类型中使用时
- **通用展示逻辑**：当展示逻辑不特定于某个 Block 类型时
- **标准化 UI**：当需要保持 Block 详情页的一致性时

### 何时不使用

- **类型特定逻辑**：如果组件只用于某个特定 Block 类型，应该放在 `lib/blocks/{type}/widgets/`
- **功能特定组件**：如果组件只用于某个功能模块，应该放在 `lib/features/{feature}/widgets/`

## 扩展指南

### 添加新的通用组件

1. 确认组件确实需要跨多个 Block 类型使用
2. 在 `widgets/` 目录下创建组件文件
3. 添加详细的文档注释
4. 更新本 README

### 修改现有组件

修改这些组件时要特别小心，因为它们被多个地方使用：

1. 确保修改不会破坏现有功能
2. 测试所有使用该组件的 Block 类型
3. 考虑向后兼容性

## 相关文档

- [Block 类型开发指南](../../../docs/block_type_guide.md)
- [架构说明文档](../../../docs/architecture.md)
