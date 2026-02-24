# Record Block Type

档案类型 Block 的处理逻辑。

## 目录结构

```
record/
├── pages/                      # 页面组件
│   ├── record_detail_page.dart # 档案详情页
│   └── record_edit_page.dart   # 档案编辑页
├── widgets/                    # UI 组件
│   └── record_card.dart        # 档案卡片
├── record_type_handler.dart    # 类型处理器
└── README.md                   # 说明文档
```

## 类型处理器

`RecordTypeHandler` 实现了 `BlockTypeHandler` 接口，负责：

- 创建档案详情页面
- 创建档案编辑页面
- 创建档案卡片组件

## 使用方式

类型处理器在应用启动时自动注册到 `BlockRegistry`：

```dart
BlockRegistry.register(RecordTypeHandler());
```

之后可以通过 `BlockRegistry` 统一访问：

```dart
// 打开详情页
BlockRegistry.openDetailPage(context, block);

// 打开编辑页
BlockRegistry.openEditPage(context, block);

// 创建卡片
final handler = BlockRegistry.getHandler(BlockTypeIds.record);
final card = handler?.createCard(block);
```

## Block 类型 ID

档案类型的 ID 定义在 `BlockTypeIds.record`：
```dart
static const String record = 'a3dbfde11fdb0e35485c57d2fa03f0f4';
```
