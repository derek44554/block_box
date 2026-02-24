# GPS Block Type

GPS 位置类型 Block 的处理逻辑。

## 目录结构

```
gps/
├── pages/
│   ├── gps_detail_page.dart    # GPS 位置详情页
│   └── gps_edit_page.dart      # GPS 位置编辑/创建页
├── widgets/
│   ├── gps_card.dart           # GPS 位置卡片组件
│   └── gps_simple.dart         # GPS 位置简化卡片
├── gps_type_handler.dart       # GPS 类型处理器
└── README.md                   # 本文档
```

## 功能说明

### GpsDetailPage
- 显示 GPS 位置的经纬度信息
- 提供在 Google 地图中打开位置的功能
- 显示位置的介绍和时间信息
- 支持下拉刷新查看完整 Block 信息

### GpsEditPage
- 创建或编辑 GPS 位置 Block
- 自动获取当前设备位置
- 支持手动刷新位置
- 可添加位置介绍和时间信息
- 支持从痕迹页面创建（通过 traceNodeBid 参数）

### GpsCard
- 在列表中展示 GPS 位置的卡片组件
- 显示经纬度信息
- 显示位置介绍（如果有）
- 显示 BID 和时间信息

### GpsTypeHandler
- 实现 BlockTypeHandler 接口
- 注册到 BlockRegistry
- 提供 GPS 类型的详情页、编辑页和卡片组件创建方法

## Block 数据结构

```dart
{
  "model": "5b877cf0259538958f4ce032a1de7ae7",  // GPS 类型 ID
  "bid": "...",                                  // Block ID
  "intro": "位置介绍",                            // 可选
  "add_time": "2024-03-14T15:59:48+08:00",      // 时间
  "gps": {
    "longitude": 116.397128,                     // 经度
    "latitude": 39.916527                        // 纬度
  },
  "node_bid": "...",                             // 可选，关联的节点 BID
  "createdAt": "...",                            // 创建时间
  // ... 其他 Block 基础字段
}
```

## 使用示例

### 注册类型处理器

```dart
// 在 main.dart 中注册
BlockRegistry.register(GpsTypeHandler());
```

### 打开详情页

```dart
// 通过 BlockRegistry
BlockRegistry.openDetailPage(context, gpsBlock);

// 或通过 AppRouter
AppRouter.openBlockDetailPage(context, gpsBlock);
```

### 创建新的 GPS 位置

```dart
// 普通创建
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => GpsEditPage(),
  ),
);

// 从痕迹页面创建
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => GpsEditPage(traceNodeBid: nodeId),
  ),
);
```

### 编辑现有 GPS 位置

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => GpsEditPage(block: gpsBlock),
  ),
);
```

## 依赖

- `geolocator`: 用于获取设备位置
- `url_launcher`: 用于在 Google 地图中打开位置
- `flutter_localizations`: 用于日期时间选择器的本地化

## 权限要求

### iOS (Info.plist)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要访问您的位置以记录 GPS 坐标</string>
```

### Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```
