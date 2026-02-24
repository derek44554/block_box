# Core Storage Layer

存储层提供统一的本地数据持久化接口，支持多种存储实现。

## 目录结构

- `local_storage.dart` - 存储接口定义
- `preferences_storage.dart` - SharedPreferences 实现
- `cache/` - 缓存管理
  - `image_cache.dart` - 图片缓存
  - `audio_cache.dart` - 音频缓存
  - `file_cache.dart` - 文件缓存

## 使用方式

### 基本存储操作

```dart
// 获取存储实例
final storage = await PreferencesStorage.create();

// 保存数据
await storage.setString('key', 'value');
await storage.setInt('count', 42);
await storage.setBool('flag', true);

// 读取数据
final value = await storage.getString('key');
final count = await storage.getInt('count');
final flag = await storage.getBool('flag');

// 删除数据
await storage.remove('key');
```

### 缓存管理

```dart
// 图片缓存
final imageCache = ImageCacheManager();
await imageCache.cacheImage(cid, bytes);
final cachedBytes = await imageCache.getCachedImage(cid);

// 音频缓存
final audioCache = AudioCacheManager();
await audioCache.cacheAudio(cid, bytes);
```

## 注意事项

- 使用 `LocalStorage` 接口而不是直接使用 SharedPreferences
- 缓存文件存储在应用的临时目录
- 大文件应该使用缓存管理器而不是 SharedPreferences
