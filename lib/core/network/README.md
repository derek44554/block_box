# Core Network Layer

网络层负责所有与后端的通信，包括加密、请求封装和响应处理。

## 目录结构

- `api/` - API 客户端和具体的 API 实现
  - `api_client.dart` - 基础 HTTP 客户端
  - `block_api.dart` - Block 相关 API
  - `node_api.dart` - Node 相关 API
- `crypto/` - 加密和解密工具
  - `crypto_util.dart` - AES-CBC 加密工具
  - `bridge_transport.dart` - 加密传输层
- `models/` - 网络相关的数据模型
  - `connection_model.dart` - 连接配置模型
  - `api_error.dart` - API 错误模型

## 使用方式

### 发起 API 请求

```dart
// 通过 Provider 获取 ConnectionProvider
final connectionProvider = context.read<ConnectionProvider>();

// 创建 API 客户端
final blockApi = BlockApi(connectionProvider: connectionProvider);

// 发起请求
final response = await blockApi.getBlock(bid: 'xxx');
```

### 加密和解密

所有网络请求都会自动使用当前连接的密钥进行 AES-CBC 加密。加密逻辑封装在 `BridgeTransport` 中。

## 注意事项

- 所有 API 请求都通过 `/bridge/ins` 路由
- 请求和响应都使用 AES-CBC (PKCS7) 加密
- 需要确保 ConnectionProvider 中有活动的连接配置
