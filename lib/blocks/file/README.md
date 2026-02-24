# File Block Type

文件类型 Block 的处理模块。

## 目录结构

```
file/
├── pages/              # 页面组件
│   ├── file_detail_page.dart       # 文件详情页（通用）
│   ├── image_detail_page.dart      # 图片详情页
│   ├── video_detail_page.dart      # 视频详情页
│   └── image_edit_page.dart        # 图片编辑页
├── widgets/            # UI 组件
│   ├── file_card_bank.dart         # 文件卡片
│   └── image_file_card.dart        # 图片文件卡片
├── models/             # 数据模型
│   └── file_card_data.dart         # 文件卡片数据模型
├── utils/              # 工具类
│   └── file_category.dart          # 文件分类工具
└── file_type_handler.dart          # 文件类型处理器

```

## 功能说明

### 文件类型处理器 (FileTypeHandler)

实现 `BlockTypeHandler` 接口，负责：
- 创建文件详情页面
- 创建文件编辑页面（仅图片类型支持）
- 创建文件卡片组件

### 页面组件

- **FileDetailPage**: 通用文件详情页，根据文件类型展示不同内容
- **ImageDetailPage**: 图片详情页，支持图片查看和缩放
- **VideoDetailPage**: 视频详情页，支持视频播放
- **ImageEditPage**: 图片编辑页，支持图片裁剪、旋转等编辑功能

### 卡片组件

- **FileCard**: 通用文件卡片，展示文件名、类型、大小等信息
- **ImageFileCard**: 图片文件卡片，展示图片缩略图

### 数据模型

- **FileCardData**: 文件卡片数据模型，封装文件相关信息

### 工具类

- **file_category.dart**: 文件分类工具，根据扩展名判断文件类型

## 使用方式

文件类型处理器会在应用启动时自动注册到 `BlockRegistry`。

```dart
// 在 main.dart 或 dependency_injection.dart 中注册
BlockRegistry.register(FileTypeHandler());
```

## Block 数据结构

文件类型 Block 的数据结构示例：

```json
{
  "bid": "c4238dd0d3d95db7b473a",
  "model": "c4238dd0d3d95db7b473adb449f6d282",
  "fileName": "example.pdf",
  "intro": "文件描述",
  "ipfsSize": 1024000,
  "encryption": {
    "isSupported": true
  }
}
```
