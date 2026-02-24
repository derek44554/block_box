# Set Block Type

集合类型 Block 的处理模块。

## 概述

集合类型用于组织和管理一组相关的 Block，支持创建、编辑和查看集合内容。集合可以包含任意类型的 Block。

## 组件

### Pages

- `set_detail_page.dart` - 集合详情页面，展示集合信息和包含的 Block
- `set_edit_page.dart` - 集合编辑页面，支持修改集合信息

### Widgets

- `collection_card.dart` - 集合卡片组件，用于列表展示

### Handler

- `set_type_handler.dart` - 集合类型处理器，注册到 BlockRegistry

## 数据结构

集合 Block 包含以下字段：

- `model` - 类型 ID (1635e536a5a331a283f9da56b7b51774)
- `bid` - Block ID
- `title` - 标题
- `intro` - 简介
- `coverUrl` - 封面图片 URL（可选）
- `tags` - 标签列表
- `createdAt` - 创建时间
- `updatedAt` - 更新时间

## 功能特性

- 集合信息展示
- 包含的 Block 列表
- 链接计数
- 标签展示
- 编辑集合信息
- 下拉刷新

## 使用方式

### 注册处理器

```dart
BlockRegistry.register(SetTypeHandler());
```

### 打开详情页

```dart
BlockRegistry.openDetailPage(context, setBlock);
```

### 打开编辑页

```dart
BlockRegistry.openEditPage(context, setBlock);
```

### 创建卡片

```dart
CollectionCard(block: setBlock);
```
