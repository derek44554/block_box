# Core Utils

工具类库，提供各种辅助功能。

## 目录结构

- `formatters/` - 格式化工具
  - `bid_formatter.dart` - BID 格式化
  - `date_formatter.dart` - 日期格式化
  - `time_formatter.dart` - 时间格式化
  - `file_size_formatter.dart` - 文件大小格式化
  - `url_formatter.dart` - URL 格式化
- `generators/` - 生成器
  - `bid_generator.dart` - BID 生成器
- `helpers/` - 辅助工具
  - `platform_helper.dart` - 平台判断
  - `file_helper.dart` - 文件操作
  - `permission_helper.dart` - 权限管理
- `extensions/` - 扩展方法
  - `string_extensions.dart` - 字符串扩展
  - `date_extensions.dart` - 日期扩展
  - `list_extensions.dart` - 列表扩展

## 使用方式

### 格式化工具

```dart
// BID 格式化
final formatted = formatBid('5dd37da985bc497f5578ac00371911dc');
// 输出: 5dd37da985...371911dc

// 日期格式化
final dateStr = formatDate(DateTime.now());
// 输出: 2025-12-07

// 文件大小格式化
final sizeStr = formatFileSize(1024 * 1024);
// 输出: 1.0 MB
```

### BID 生成

```dart
// 生成新的 BID
final bid = await generateBidV2(connectionProvider);
```

### 平台判断

```dart
if (PlatformHelper.isMacOS) {
  // macOS 特定逻辑
} else if (PlatformHelper.isIOS) {
  // iOS 特定逻辑
}
```

### 时间格式化

```dart
// 生成带时区的 ISO8601 时间戳
final timestamp = nowIso8601WithOffset();
// 输出: 2025-12-07T15:30:00+08:00

// 格式化指定时间
final formatted = iso8601WithOffset(DateTime.now());
```

## 注意事项

- 使用这些工具类保持格式的一致性
- 不要在各个模块中重复实现相同的功能
- 新增工具类应该添加到对应的子目录
- 工具方法应该是纯函数，无副作用
