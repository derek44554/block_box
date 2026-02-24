# Creed Block Type

信条类型 Block 的处理模块。

## 概述

信条类型用于记录和管理个人信条、座右铭、人生哲学等重要的思想内容。信条Block专注于内容的展示和管理，支持主要内容和补充说明。

## 组件

### Pages

- `creed_detail_page.dart` - 信条详情页面，展示完整的信条内容和简介
- `creed_edit_page.dart` - 信条编辑页面，支持创建和修改信条

### Widgets

- `creed_card.dart` - 信条卡片组件，用于列表展示，只显示主要内容

### Handler

- `creed_type_handler.dart` - 信条类型处理器，注册到 BlockRegistry

## 数据结构

信条 Block 包含以下字段：

- `model` - 类型 ID (278d4f8ef33268051889232365568160)
- `bid` - Block ID
- `content` - 信条内容（必填，主要字段）
- `intro` - 简介（可选，补充说明）
- `tags` - 标签列表
- `createdAt` - 创建时间
- `updatedAt` - 更新时间

## 功能特性

### 卡片显示
- 只显示 `content` 字段内容
- 绿色主题设计，使用引号图标
- 支持内容截断（最多3行）
- **显示标签**：如果信条有标签，会在内容下方显示（最多显示3个标签）
- 显示BID和创建时间
- **支持点击打开详情页面**

### 详情页面
- **统一的UI风格**：与其他Block类型保持一致的设计模式
- 完整显示 `content` 内容，带绿色边框突出显示
- 如果存在 `intro` 则单独显示在简介区域
- 支持标签管理（查看和添加标签）
- **统一的操作模式**：
  - 下拉刷新查看完整Block详情
  - 快捷操作按钮（原始数据、修改）
  - 链接管理（链接数量显示、链接页面、外链页面）
  - BID信息显示和复制

### 编辑功能
- `content` 为必填字段
- `intro` 为可选字段
- 支持多行文本输入
- 集成基础Block编辑功能（标签、权限等）

## 使用方式

### 注册处理器

```dart
BlockRegistry.register(CreedTypeHandler());
```

### 打开详情页

```dart
BlockRegistry.openDetailPage(context, creedBlock);
```

### 打开编辑页

```dart
BlockRegistry.openEditPage(context, creedBlock);
```

### 创建卡片

```dart
CreedCard(block: creedBlock);
```

### 创建可点击的卡片

```dart
// 使用默认点击行为（打开详情页面）
CreedCard(block: creedBlock);

// 使用自定义点击行为
CreedCard(
  block: creedBlock,
  onTap: () {
    // 自定义点击处理
  },
);
```

### 创建新信条

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => CreedEditPage(
      block: BlockModel(data: {}),
    ),
  ),
);
```

## 设计理念

信条类型的设计遵循以下原则：

1. **内容为王**：`content` 是核心字段，在卡片中直接展示
2. **简洁展示**：卡片只显示主要内容，保持简洁
3. **详细说明**：详情页可展示完整的 `intro` 补充信息
4. **视觉识别**：使用绿色主题和引号图标，便于识别
5. **易于管理**：支持标签分类和搜索功能

## 相关文件

- `lib/blocks/common/block_registry.dart` - Block类型注册表
- `lib/blocks/common/block_type_ids.dart` - Block类型ID常量
- `lib/core/models/block_model.dart` - Block数据模型
- `lib/app/dependency_injection.dart` - 依赖注入配置