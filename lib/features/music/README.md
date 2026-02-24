# 音乐页面模块

## 概述

音乐页面是一个用于播放和管理音乐的功能模块，采用左右滑动的布局设计，包含"播放"和"集合"两个分段。

## 架构设计

### 页面结构

- **主页面**: `music_page.dart` - 使用 `SegmentedPageScaffold` 实现分段切换
- **播放页面**: `widgets/music_play_page.dart` - 显示音乐播放列表
- **集合页面**: `widgets/music_collection_page.dart` - 管理音乐集合
- **播放器组件**: `widgets/music_player.dart` - 底部音乐播放器

### 数据模型

- **MusicItem** (`music_models.dart`): 音乐项数据模型
  - 包含标题、艺术家、时长、封面等信息
  - 从 BlockModel 构建
  
- **MusicCollection** (`music_models.dart`): 音乐集合数据模型
  - 支持标记为播放列表
  - 持久化到本地存储

### 状态管理

**MusicProvider** (`state/music_provider.dart`) 负责：
- 集合管理（添加、删除、排序）
- 播放状态管理（当前播放、播放列表、播放/暂停）
- 数据持久化到 SharedPreferences

## 主要功能

### 播放页面

1. **音乐列表显示**
   - 显示序号或播放图标
   - 音乐封面、标题、艺术家
   - 时长显示
   - 更多选项菜单

2. **播放控制**
   - 点击音乐项开始播放
   - 设置播放列表
   - 查看音乐详情

3. **数据加载**
   - 从标记为播放列表的集合加载音乐
   - 过滤音频文件（.mp3, .m4a, .aac, .ogg, .wav, .flac）
   - 支持分页加载

### 集合页面

1. **集合管理**
   - 显示所有音乐集合
   - 添加新集合（通过 BID）
   - 删除集合（带确认）
   - 标记/取消标记为播放列表

2. **集合操作**
   - 点击选中/取消选中
   - 长按显示操作菜单
   - 实时状态更新

### 底部播放器

1. **播放信息显示**
   - 当前音乐封面
   - 标题和艺术家
   
2. **播放控制**
   - 上一首/下一首
   - 播放/暂停
   - 仅在有音乐播放时显示

## UI 组件

### 集合卡片 (`music_collection_card.dart`)
- 显示集合标题和简介
- "已加入播放"标签
- 选中状态动画

### 集合列表 (`music_collection_list.dart`)
- 滚动列表
- 空状态、加载中、错误状态
- 底部添加按钮

## 使用方式

```dart
// 在应用中导航到音乐页面
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const MusicPage()),
);
```

## 数据流

1. **加载音乐**
   - MusicCollectionPage 从服务器获取集合数据
   - 保存到 MusicProvider
   - MusicPlayPage 从播放列表集合加载音乐

2. **播放音乐**
   - 用户点击音乐项
   - 设置当前播放和播放列表到 MusicProvider
   - MusicPlayer 组件显示并响应控制

3. **持久化**
   - 集合数据保存到 SharedPreferences
   - 键名: `music_collections_data`
   - 格式: JSON 字符串列表

## 扩展说明

### 添加新功能

1. **音频播放实现**: 当前仅 UI 框架，需集成音频播放库（如 `audioplayers` 或 `just_audio`）
2. **进度控制**: 可在 MusicPlayer 中添加进度条
3. **播放模式**: 支持循环、随机播放
4. **收藏功能**: 支持收藏单曲

### 自定义样式

所有组件遵循黑色主题和白色线条的设计风格，可在各组件中统一调整颜色和间距。

## 依赖

- `provider`: 状态管理
- `shared_preferences`: 数据持久化
- Block API: 网络数据获取

## 注意事项

1. 音频文件通过 IPFS CID 标识
2. 集合 BID 需要是有效的 32 位块 ID
3. 播放器目前仅显示 UI，实际音频播放需要额外实现
4. 音频格式过滤基于文件扩展名

