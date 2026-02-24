# Core Theme

主题层定义应用的视觉风格，包括颜色、文本样式和组件主题。

## 目录结构

- `app_theme.dart` - 主题配置
- `app_colors.dart` - 颜色常量
- `app_text_styles.dart` - 文本样式
- `app_dimensions.dart` - 尺寸常量

## 使用方式

### 应用主题

```dart
MaterialApp(
  theme: AppTheme.dark(),
  // ...
)
```

### 使用颜色

```dart
import 'package:block_app/core/theme/app_colors.dart';

Container(
  color: AppColors.surface,
  child: Text(
    'Hello',
    style: TextStyle(color: AppColors.onSurface),
  ),
)
```

### 使用文本样式

```dart
import 'package:block_app/core/theme/app_text_styles.dart';

Text(
  'Title',
  style: AppTextStyles.headline,
)
```

## 设计风格

- 主题：深色主题，黑色背景
- 主色调：灰色系 (#9E9EA2)
- 强调色：白色线条
- 风格：简洁、现代

## 注意事项

- 使用主题中定义的颜色，避免硬编码颜色值
- 保持视觉风格的一致性
- 新增颜色应该添加到 `app_colors.dart`
