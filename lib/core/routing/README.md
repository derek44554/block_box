# Core Routing

路由层管理应用的页面导航和路由配置。

## 目录结构

- `app_router.dart` - 路由配置和生成
- `route_names.dart` - 路由名称常量
- `navigation_service.dart` - 导航服务

## 使用方式

### 命名路由导航

```dart
// 导航到命名路由
Navigator.pushNamed(context, AppRoutes.photo);

// 使用 NavigationService
NavigationService.navigateTo(AppRoutes.settings);
```

### Block 详情页导航

```dart
// 使用统一的 Block 详情页导航
await NavigationService.navigateToBlockDetail(blockModel);

// 或使用 AppRouter
await AppRouter.openBlockDetailPage(context, blockModel);
```

### Block 编辑页导航

```dart
// 打开编辑页面
final updatedBlock = await NavigationService.navigateToBlockEdit(blockModel);
if (updatedBlock != null) {
  // 处理更新后的 Block
}
```

## 路由配置

所有路由在 `app_router.dart` 中集中配置，使用 `onGenerateRoute` 方法动态生成路由。

## 注意事项

- 使用路由名称常量而不是硬编码字符串
- Block 类型的导航统一使用 BlockRegistry
- 复杂的导航逻辑封装在 NavigationService 中
