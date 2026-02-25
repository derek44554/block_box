# BlockBox

一个基于 Flutter 的 Block 数据管理应用，采用 Feature-First 架构设计。

## 目录

- [核心概念](#核心概念)
- [架构设计](#架构设计)
- [目录结构](#目录结构)
- [设计风格](#设计风格)
- [功能模块](#功能模块)
- [网络层](#网络层)
- [开发规范](#开发规范)
- [开发指南](#开发指南)

## 核心概念

### Block 数据模型

数据是块（Block），每一条数据就是一个 Block。

- **BID**：每个块都有唯一的 BID（Block ID），21个字符的标识符
- **Model**：`model` 字段标记块的类型（如 document、image、set 等）
- **统一模型**：所有 Block 使用统一的 `BlockModel` 类，通过 `model` 字段区分类型，不为每个类型创建独立的模型类

### Block 类型系统

应用支持多种 Block 类型，每种类型有专门的展示和编辑方式：

- **document**：文档类型，包含标题和内容
- **article**：文章类型，只读展示
- **set**：集合类型，包含多个子 Block
- **file**：文件类型，支持图片、视频等
- **service**：服务类型，存储加密的密码和 API Key
- **user**：用户类型
- **record**：档案类型
- **gps**：GPS 位置类型

## 架构设计

### 架构模式

采用 **Feature-First + Layered** 混合架构：

```
┌─────────────────────────────────────────┐
│         App Entry (app/)                │
│      main.dart, app.dart                │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│      Presentation Layer                 │
│  ┌──────────┐    ┌──────────┐          │
│  │ Features │    │  Blocks  │          │
│  └──────────┘    └──────────┘          │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│      Business Logic Layer               │
│  ┌──────────┐    ┌──────────┐          │
│  │Providers │    │ Services │          │
│  └──────────┘    └──────────┘          │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│   Core Infrastructure (core/)           │
│  Network | Storage | Theme | Routing    │
└─────────────────────────────────────────┘
```

### 架构原则

1. **功能优先（Feature-First）**：业务功能按模块组织
2. **分层设计（Layered）**：核心基础设施按技术层次组织
3. **类型驱动（Type-Driven）**：Block 类型处理逻辑独立组织
4. **依赖注入**：通过 Provider 管理服务和状态
5. **单向数据流**：UI 层通过 Provider 访问状态

## 目录结构

```
lib/
├── app/                    # 应用入口和配置
│   ├── main.dart          # 应用入口点
│   ├── app.dart           # App Widget 定义
│   ├── app_config.dart    # 应用配置常量
│   └── dependency_injection.dart  # 依赖注入配置
│
├── core/                   # 核心基础设施
│   ├── network/           # 网络层（API、加密）
│   ├── storage/           # 本地存储（缓存、偏好设置）
│   ├── theme/             # 主题和样式
│   ├── routing/           # 路由管理
│   ├── widgets/           # 通用 UI 组件
│   ├── utils/             # 工具类（格式化、生成器）
│   └── models/            # 核心数据模型
│
├── features/              # 功能模块
│   ├── photo/            # 相册功能
│   ├── collect/          # 收藏功能
│   ├── music/            # 音乐功能
│   ├── home/             # 首页
│   ├── settings/         # 设置
│   └── ...               # 其他功能模块
│
├── blocks/                # Block 类型处理
│   ├── common/           # Block 类型注册表
│   ├── document/         # 文档类型
│   ├── article/          # 文章类型
│   ├── set/              # 集合类型
│   ├── file/             # 文件类型
│   └── ...               # 其他 Block 类型
│
└── components/            # 跨模块共享组件
    ├── block/            # Block 相关组件（卡片工厂、网格布局、通用 UI）
    └── layout/           # 布局组件（分段页面、最近列表）
```

详细的目录结构说明请参见 [架构说明文档](docs/architecture.md)。

## 设计风格

- **主题**：深色主题，黑色背景
- **主色调**：灰色系 (#9E9E9EA2)
- **强调色**：白色线条
- **风格**：简洁、现代

## App 架构

### 页面骨架

应用内存在多个带顶部分段切换的页面（如 `FavoritePage`、`PhotoPage`、`LinkPage`、`AIPage`）。
这些页面统一由 `lib/components/layout/segmented_page_scaffold.dart` 提供的 `SegmentedPageScaffold` 构建。

- 仅需传入标题、分段名称和页面列表即可构建；内部自动管理 `PageController` 与当前索引。
- 标题样式保持统一，如需交互可指定 `onTitleTap`。
- 分段切换采用共享的 `PageSegmentedControl`，确保视觉与动画一致。

### UI 组件

#### 弹窗样式

需要统一输入弹窗时，使用 `lib/widgets/app_dialog.dart` 提供的组件：

- `AppDialog`：封装了深色背景、圆角、统一标题和内容间距，可传入内容与按钮区域。
- `AppDialogTextField`：为弹窗内部输入框提供统一的标签、边框与错误提示样式。
- 在连接设置页面等场景，可结合 `showDialog` 使用，确保弹窗风格一致。

#### 操作列表与确认弹窗

为统一常见的底部操作列表和二次确认弹窗，提供了以下两个公共组件：

- **操作列表 (`ActionSheet`)**：通过 `lib/widgets/action_sheet.dart` 调用。
  - 使用 `showModalBottomSheet` 展示，传入 `ActionSheet` 实例。
  - `ActionSheet` 包含 `title` 和 `actions` 列表，其中每个 `ActionItem` 可定义标签、图标、点击事件，并通过 `isDestructive` 标为危险操作（红色）。
  - 已内置顶部拖拽手柄和符合整体设计风格的圆角、背景色。

- **确认弹窗 (`showConfirmationDialog`)**：通过 `lib/widgets/confirmation_dialog.dart` 调用。
  - 这是一个便捷函数，内部封装了 `AppDialog`。
  - 只需传入 `context`、`title`、`content` 即可快速生成带“确认”和“取消”按钮的对话框。
  - 可通过 `confirmText`、`cancelText` 自定义按钮文字，并通过 `isDestructive` 将确认按钮标为危险操作（红色背景）。

### 导航约定

为统一不同类型 Block 的编辑入口，所有“修改”操作都应通过 `lib/app_router.dart` 中提供的 `AppRouter.openBlockEditPage` 方法进行导航。

- **调用方式**：
  ```dart
  final result = await AppRouter.openBlockEditPage(context, blockModel);
  if (result != null) {
    // 处理编辑后返回的更新后的 BlockModel
  }
  ```
- **工作原理**：该方法接收 `BuildContext` 和一个 `BlockModel` 实例，它会读取 `block.maybeString('model')` 字段来判断块类型，然后导航到对应的编辑页面（例如 `SetEditPage`、`DocumentEditPage`）。
- **返回值**：编辑页面在保存成功后会返回更新后的 `BlockModel`，调用方可以接收此返回值来刷新界面状态。
- **未支持类型**：如果传入的 `BlockModel` 类型没有对应的编辑页面，该方法会弹出一个 `SnackBar` 提示用户“暂不支持此类型的块编辑”，并返回 `null`。
- **扩展性**：未来若要支持新的块类型编辑，只需在 `openBlockEditPage` 方法的 `switch` 语句中增加一个新的 `case` 即可，无需修改调用方的代码。

此设计将导航逻辑与判断逻辑集中管理，避免在 `BlockDetailPage` 等多处进行重复的 `if/else` 或 `switch` 判断，使代码更清晰、易于维护。

## 功能模块

### 收藏管理

收藏页（`CollectPage`）依赖 `CollectProvider` 管理本地标签与集合数据，持久化在 `shared_preferences` 中。

- 标签通过“标签”区域加号弹窗创建，调用 `CollectProvider.addTag()` 保存。
- 集合与集合项均通过统一弹窗新增，集合项要求填写标题与 BID，调用 `CollectProvider.addEntry()`、`addItem()`。
- 所有模型定义于 `lib/models/collect_models.dart`，页面组件读取 Provider 数据并实时刷新。

### 相册集合

照片页（`PhotoPage`）支持在集合分段中手动新增集合，并将数据序列化到本地。

- 新增集合弹窗通过 `_PhotoCollectionDialog` 实现，输入标题、简介与 BID 并保存。
- 持久化逻辑保存在 `lib/pages/photo/photo_page.dart`，使用 `shared_preferences` 维护 `photo_collections`。
- 默认集合样例仍由 `_buildCollections()` 提供，首次运行若无数据将写入样例。

### 图片处理核心

- **数据来源**: 图片数据通过 `image_picker` 从用户相册获取。元数据（如GPS、时间）通过 `exif` 库从文件二进制数据中提取。
- **时间戳**: 在创建图片Block时，其 `created_at` 字段应尽可能接近原始拍摄时间。获取优先级为：1. EXIF拍摄时间 > 2. 文件修改时间。`文件修改时间` 是在没有拍摄时间时的可靠备选。所有时间都通过 `iso8601WithOffset()` 格式化为带时区的字符串。
- **核心工具**: `lib/utils/ipfs_file_helper.dart` 负责从IPFS网络加载、解密和缓存图片。
- **UI展示**: `ImageFileCard` 用于列表，`ImageDetailPage` 用于详情。
- **列表性能**: 包含图片的列表使用 `cacheExtent` 属性进行性能优化，以保证滑动流畅。

### 加密服务管理

设置模块提供了加密服务（API密钥、密码等）的详情查看和导出功能：

- **详情页面**: `ApiKeyDetailPage` 展示服务Block的完整信息（BID、Key、Model等）
- **字段复制**: 支持一键复制BID、Key、Model等字段到剪贴板
- **密钥导出**: 支持将密钥信息导出为YAML格式文件到设备文档目录
- **UI风格**: 采用深色主题，卡片式布局，统一的视觉风格

## 网络层

### 请求协议

全部的请求都是通过一个URL接口完成的 http路由只有一个

发送的数据 路由`/bridge/ins`

所有网络请求均发送到当前选中连接的根地址下的 `/bridge/ins` 路由，并使用当前连接所配置的 Base64 对称密钥进行 AES-CBC（PKCS7）加密。HTTP 请求体统一为：

```json
{
  "text": "<AES 加密后再 Base64 编码的字符串>"
}
```

> 自 2025-11 起，后端响应同样使用该密钥加密，前端必须按相同步骤解密后才能得到业务数据。

加密前的原始载荷结构如下：

```json
{
  "protocol": "cert",
  "routing": "/block/block/get",
  "data": { "bid": "..." },
  "receiver": "",
  "wait": true,
  "timeout": 60
}
```

- `protocol` 是发送协议 open和cert
- `routing` 这个路由是Block网络的路由 这个不同路由会进入不同的处理函数 类似http的路由概念
- `data` 发送的数据
- `receiver` 通常为空就可以 代表接收处理的节点 可以是一个节点的bid或者""或者"*"代表全部节点
- `wait` 是否等待响应数据的返回
- `timeout` 等待相应数据的等待时间

但这些整个数据需要进行加密后再进行 http 传输；服务端响应的 `BridgeRes` 同样封装在 `{"text": "<Base64密文>"}` 中返回。前端流程可概括为：

- 构造原始协议 JSON，并使用 `CryptoUtil.encryptBase64`（或同规范实现）得到 `cipherText`。
- POST `{"text": cipherText}` 至 `/bridge/ins`。
- 解析响应中的 `text` 字段，调用 `CryptoUtil.decryptBase64` 解密后再进行 JSON 解析。

若解密失败，提示“响应解密失败，请检查密钥”并记录原始字符串以便排查。

### 加密与 API

- `lib/network/crypto_util.dart`：封装 AES-CBC PKCS7 的加密/解密工具，会使用随机 IV 并将 `iv + ciphertext` 一并编码为 Base64。
- `lib/network/api_client.dart`：读取 `ConnectionProvider.activeConnection` 的地址与 Base64 密钥，对载荷进行加密后 POST 到 `/bridge/ins`。
- `lib/network/block_api.dart`：针对区块相关指令的高层 API，例如 `getBlock` 自动拼装 `routing` 与 `data`。

### Block API 示例

**示例：获取指定 BID 的区块**

```dart
final blockApi = BlockApi(connectionProvider: context.read<ConnectionProvider>());
final response = await blockApi.getBlock(bid: '5dd37da985bc497f5578ac00371911dc');
```

## 开发规范

### 代码约定

- **统一数据模型**：除特殊说明外，卡片与详情页面默认接收 `BlockModel`，通过 `block.maybeString()` / `block.list<T>()` 等安全方法读取字段，避免直接访问 Map。`DocumentDetailPage` 额外支持仅传入 `bid`，进入后会自动向服务器获取最新块数据。
- **BID 生成算法**：使用 `lib/utils/bid_generator.dart` 中的 `generateBidV2()` 统一生成基于节点BID的BID。新规则为：节点BID前10个字符 + 11字节随机字符串（共21个字符）。需要确保连接状态正常且节点BID有效。
- **集合编辑页面**：集合块支持使用 `SetEditPage` 创建或修改，BID将自动基于当前连接的节点BID生成。
- **公共格式化工具**：统一使用 `lib/utils/bid_formatter.dart` 中的 `formatBid()`、`formatDate()`、`formatUrl()`；不要在各组件内重复实现。
- **统一标签组件**：使用 `lib/widgets/tag_widget.dart` 中的 `TagWidget` 显示标签，保持统一的视觉风格。
- **可选显示**：优先使用 `BlockModel` 的 `has()` 辅助判断，再决定是否渲染对应内容，避免出现硬编码判空逻辑。
- 如需新增类似工具或通用样式，优先在 `utils/` 或公共组件中扩展，保持代码一致性。

### 代码习惯

在写共有方法时 要写上足够多的注释代码

每个卡片和详情页 在开头要写上注释描述大体

不需要使用git

### 时间格式

- 所有新增/更新时间戳统一使用 `lib/utils/time_formatter.dart` 中的工具方法。
- `nowIso8601WithOffset()` / `iso8601WithOffset()` 会生成带本地时区偏移的 ISO8601 字符串，例如 `2025-10-16T04:30:44+08:00`。
- 新建文档、集合等场景请直接调用上述工具，避免手工拼接。

### 图片时间戳处理

为确保图片时间的准确性与一致性，在从图片文件提取时间戳时，遵循以下优先级顺序：

1.  **EXIF 拍摄时间 (`DateTimeOriginal`)**：这是最优先、最准确的时间，直接反映了照片的拍摄时刻。
2.  **文件修改时间 (`Modification Time`)**：当 EXIF 信息缺失时（例如图片经过编辑或来自截图），**修改时间**是比创建时间更可靠的备选方案。因为文件内容（像素数据）的最后修改时间通常更接近图片的原始生成时间。
3.  **文件创建时间 (`Creation Time`)**：这是**最不可靠**的指标，应避免使用。当文件在不同设备、不同磁盘分区之间复制或通过网络传输时，其“创建时间”会被重置为**复制操作发生的当前时间**，这会严重偏离图片的真实时间。

当前 `ImageEditPage` 的实现已遵循此规范，优先使用 EXIF 时间，并以降级到**修改时间**作为备选策略。

# block_app


## 开发指南

### 添加新功能模块

参见 [功能模块开发指南](docs/feature_module_guide.md)，了解如何创建新的功能模块。

### 添加新 Block 类型

参见 [Block 类型开发指南](docs/block_type_guide.md)，了解如何添加新的 Block 类型。

### 架构文档

参见 [架构说明文档](docs/architecture.md)，了解完整的架构设计和目录结构。

### 图片加载

参见 [图片加载最佳实践指南](docs/image_loading_guide.md)，了解如何正确加载图片并使用缓存。

## 性能优化

### 缓存系统

应用实现了两级缓存系统，大幅提升图片加载速度：

- **Block 元数据缓存**：缓存 Block 的完整数据，避免重复的 API 请求
- **图片数据缓存**：缓存图片本身，避免重复下载

**优化效果**：
- 再次访问时速度提升 95%+（从 ~210ms 降至 ~10ms）
- 完全避免重复的网络请求
- 显著改善用户体验

详见 [缓存优化总结](CACHE_OPTIMIZATION_SUMMARY.md) 和 [缓存系统说明](lib/core/storage/cache/README.md)。

## 相关文档

### 核心文档
- [架构说明文档](docs/architecture.md) - 完整的架构设计和目录结构说明
- [功能模块开发指南](docs/feature_module_guide.md) - 如何创建新的功能模块
- [Block 类型开发指南](docs/block_type_guide.md) - 如何添加新的 Block 类型
- [图片加载最佳实践指南](docs/image_loading_guide.md) - 如何正确加载图片并使用缓存

### 性能优化
- [缓存优化总结](CACHE_OPTIMIZATION_SUMMARY.md) - 缓存系统优化说明
- [缓存系统说明](lib/core/storage/cache/README.md) - BlockCache 使用指南

### 模块文档
- [Core Network README](lib/core/network/README.md) - 网络层使用说明
- [Core Storage README](lib/core/storage/README.md) - 存储层使用说明
- [Core Theme README](lib/core/theme/README.md) - 主题系统使用说明
- [Core Routing README](lib/core/routing/README.md) - 路由系统使用说明
- [Core Widgets README](lib/core/widgets/README.md) - 通用组件使用说明
- [Core Utils README](lib/core/utils/README.md) - 工具类使用说明
