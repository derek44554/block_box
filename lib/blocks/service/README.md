# Service Block 类型

服务类型 Block 的处理逻辑，包含详情页、编辑页和卡片组件。

## 目录结构

```
service/
├── pages/
│   ├── service_detail_page.dart    # 服务详情页
│   └── service_edit_page.dart      # 服务编辑页
├── widgets/
│   └── service_card.dart           # 服务卡片组件
├── utils/
│   └── service_decryptor.dart      # 服务解密工具
├── service_type_handler.dart       # 服务类型处理器
└── README.md                       # 本文档
```

## 功能说明

### 服务详情页 (ServiceDetailPage)

展示服务类型 Block 的详细信息，包括：
- 服务名称和简介
- 服务配置信息
- 加密的服务数据

### 服务编辑页 (ServiceEditPage)

提供服务类型 Block 的编辑功能，支持：
- 编辑服务名称和简介
- 配置服务参数
- 加密服务敏感数据

### 服务卡片 (ServiceCard)

在列表中展示服务类型 Block 的卡片组件，显示：
- 服务名称
- 服务简介
- 服务图标

### 服务解密工具 (ServiceDecryptor)

提供服务数据的加密和解密功能。

## 类型处理器

`ServiceTypeHandler` 实现了 `BlockTypeHandler` 接口，负责：
- 创建服务详情页
- 创建服务编辑页
- 创建服务卡片组件

## 注册

在应用启动时注册服务类型处理器：

```dart
BlockRegistry.register(ServiceTypeHandler());
```

## Block 类型 ID

服务类型的 ID 定义在 `BlockTypeIds.service` 中：
```dart
static const String service = '81b0bc8db4f678300d199f5b34729282';
```
