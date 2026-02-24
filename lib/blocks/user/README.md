# User Block Type

用户类型 Block 的处理逻辑。

## 目录结构

```
user/
├── pages/              # 页面
│   ├── user_detail_page.dart    # 用户详情页
│   └── user_edit_page.dart      # 用户编辑页
├── widgets/            # 组件
│   └── user_card.dart           # 用户卡片
├── user_type_handler.dart       # 用户类型处理器
└── README.md
```

## 类型 ID

- **Type ID**: `71b6eb41f026842b3df6b126dfe11c29`
- **常量**: `BlockTypeIds.user`

## 功能

### 详情页 (UserDetailPage)

显示用户的详细信息，包括：
- 用户基本信息
- 用户头像
- 用户简介
- 其他用户相关数据

### 编辑页 (UserEditPage)

提供用户信息的编辑功能：
- 编辑用户基本信息
- 更新用户头像
- 修改用户简介

### 卡片组件 (UserCard)

在列表中展示用户的卡片视图：
- 显示用户头像
- 显示用户名称
- 显示用户简介摘要

## 使用方式

### 注册类型处理器

在应用启动时注册：

```dart
BlockRegistry.register(UserTypeHandler());
```

### 打开详情页

```dart
BlockRegistry.openDetailPage(context, userBlock);
```

### 打开编辑页

```dart
BlockRegistry.openEditPage(context, userBlock);
```

### 创建卡片

```dart
final handler = BlockRegistry.getHandler(BlockTypeIds.user);
final card = handler?.createCard(userBlock);
```

## 数据结构

用户 Block 的数据结构示例：

```json
{
  "bid": "...",
  "model": "71b6eb41f026842b3df6b126dfe11c29",
  "title": "用户名称",
  "intro": "用户简介",
  "avatar": "...",
  "created_at": "...",
  "updated_at": "..."
}
```
