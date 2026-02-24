# Article Block Type

文章类型 Block 的处理模块。

## 概述

文章类型用于展示长篇内容，支持 Markdown 格式。文章内容存储在 IPFS 上，通过 CID 引用。

## 组件

### Pages

- `article_detail_page.dart` - 文章详情页面，支持 Markdown 渲染和下拉刷新

### Widgets

- `article_card.dart` - 文章卡片组件，用于列表展示

### Handler

- `article_type_handler.dart` - 文章类型处理器，注册到 BlockRegistry

## 数据结构

文章 Block 包含以下字段：

- `model` - 类型 ID (52da1e115d0a764b43c90f6b43284aa9)
- `bid` - Block ID
- `title` - 标题
- `intro` - 简介
- `coverUrl` - 封面图片 URL（可选）
- `tags` - 标签列表
- `cid` - 文章内容的 IPFS CID
- `createdAt` - 创建时间

## 功能特性

- Markdown 内容渲染
- 封面图片展示
- 标签展示
- 下拉刷新
- 从 IPFS 加载内容

## 使用方式

### 注册处理器

```dart
BlockRegistry.register(ArticleTypeHandler());
```

### 打开详情页

```dart
BlockRegistry.openDetailPage(context, articleBlock);
```

### 创建卡片

```dart
ArticleCard(block: articleBlock);
```
