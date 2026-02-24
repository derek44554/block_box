# Core Widgets

本目录包含应用中可复用的通用 UI 组件。这些组件独立于具体业务逻辑，可以在整个应用中使用。

## 目录结构

```
widgets/
├── dialogs/          # 对话框组件
├── buttons/          # 按钮组件
├── inputs/           # 输入组件
├── layouts/          # 布局组件
├── loading/          # 加载指示器
└── common/           # 其他通用组件
```

## 组件分类

### Dialogs（对话框）

- **AppDialog**: 统一的弹窗容器样式，提供一致的标题、背景与间距
- **AppDialogTextField**: 弹窗内的文本输入组件
- **confirmation_dialog**: 通用确认对话框，支持确认/取消操作

### Common（通用组件）

- **ActionSheet**: 从底部弹出的操作列表，符合应用整体设计风格
- **TagWidget**: 统一标签组件，用于显示标签列表
- **TagNameDialog**: 输入标签名称的弹窗

### Layouts（布局组件）

- **SegmentedPageScaffold**: 通用的分页骨架，提供顶部分段控制和页面切换
- **PageSegmentedControl**: 分段控制器，用于多个页面顶部的 PageView 选项切换

## 使用规范

### 导入路径

使用绝对路径导入核心组件：

```dart
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';
import 'package:block_app/core/widgets/common/action_sheet.dart';
import 'package:block_app/core/widgets/layouts/segmented_page_scaffold.dart';
```

### 设计原则

1. **独立性**: 组件不应依赖具体的业务逻辑
2. **可复用性**: 组件应该在多个场景下都能使用
3. **一致性**: 保持统一的设计风格和交互模式
4. **可配置性**: 通过参数提供灵活的配置选项

### 添加新组件

在添加新的通用组件时：

1. 确定组件的分类（dialogs、buttons、inputs、layouts、common）
2. 在对应目录下创建组件文件
3. 为组件添加详细的文档注释
4. 确保组件的独立性和可复用性
5. 更新本 README 文档

## 示例

### 使用 AppDialog

```dart
showDialog(
  context: context,
  builder: (context) => AppDialog(
    title: '提示',
    content: Text('这是一个示例对话框'),
    actions: Row(
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('确认'),
        ),
      ],
    ),
  ),
);
```

### 使用 ActionSheet

```dart
showModalBottomSheet(
  context: context,
  builder: (context) => ActionSheet(
    title: '选择操作',
    actions: [
      ActionItem(
        label: '编辑',
        icon: Icons.edit,
        onTap: () {
          Navigator.pop(context);
          // 执行编辑操作
        },
      ),
      ActionItem(
        label: '删除',
        icon: Icons.delete,
        isDestructive: true,
        onTap: () {
          Navigator.pop(context);
          // 执行删除操作
        },
      ),
    ],
  ),
);
```

### 使用 SegmentedPageScaffold

```dart
SegmentedPageScaffold(
  title: '我的页面',
  segments: ['选项1', '选项2', '选项3'],
  pages: [
    Page1Widget(),
    Page2Widget(),
    Page3Widget(),
  ],
  initialIndex: 0,
  onIndexChanged: (index) {
    print('切换到页面: $index');
  },
)
```
