# 缓存系统说明

本目录包含应用的缓存实现，用于优化性能和减少网络请求。

## BlockCache - Block 元数据缓存

### 功能
`BlockCache` 提供 Block 元数据的两级缓存（内存 + 磁盘），避免重复的 API 请求。

### 使用场景
- 用户详情页面加载头像时，需要先获取头像 Block 的元数据（包含 CID 等信息）
- Record 卡片和详情页面加载封面图片时，需要获取封面 Block 的元数据
- 任何需要通过 BID 获取 Block 数据的场景

### 使用方法

```dart
import 'package:block_app/core/storage/cache/block_cache.dart';

// 1. 尝试从缓存获取
BlockModel? block = await BlockCache.instance.get(bid);

// 2. 如果缓存未命中，从 API 获取
if (block == null) {
  final api = BlockApi(connectionProvider: connection);
  final response = await api.getBlock(bid: bid);
  block = BlockModel(data: response['data']);
  
  // 3. 保存到缓存
  await BlockCache.instance.put(bid, block);
}

// 4. 使用 block 数据
```

### 缓存策略
- **内存缓存**：最多缓存 100 个 Block，使用 LRU 淘汰策略
- **磁盘缓存**：使用 SharedPreferences 持久化存储
- **TTL（过期时间）**：1 小时，过期后自动删除
- **缓存键**：使用 BID 作为唯一标识

### 优化效果
- ✅ 避免重复的网络请求
- ✅ 提升页面加载速度
- ✅ 减少网络流量消耗
- ✅ 改善用户体验

### 已优化的组件
- `lib/blocks/user/pages/user_detail_page.dart` - 用户详情页面头像加载
- `lib/blocks/user/widgets/user_card.dart` - 用户卡片头像加载
- `lib/blocks/record/pages/record_detail_page.dart` - Record 详情页面封面加载
- `lib/blocks/record/widgets/record_card.dart` - Record 卡片封面加载

## ImageCache - 图片缓存

图片本身的缓存由 `ImageCacheHelper` 和 `BlockImageLoader` 处理，详见 `image_cache.dart`。

## 缓存层次结构

```
用户请求
    ↓
BlockCache (Block 元数据)
    ↓ 缓存命中：直接返回
    ↓ 缓存未命中：API 请求
    ↓
BlockImageLoader (图片数据)
    ↓ 内存缓存命中：直接返回
    ↓ 磁盘缓存命中：加载并更新内存
    ↓ 缓存未命中：网络下载
    ↓
显示图片
```

## 维护建议

1. **定期清理**：可以在设置页面添加"清除缓存"功能
2. **监控大小**：使用 `BlockCache.instance.getStats()` 获取缓存统计信息
3. **调整参数**：根据实际使用情况调整 `maxMemoryCacheSize` 和 `cacheTTL`
