import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// API 密钥管理器
/// 
/// 负责密钥的本地持久化存储和管理
class ApiKeysManager {
  static const String _storageKey = 'api_keys_list';
  static const String _expectedModel = 'e9b837c9afa0d5d25f78eae3a76a665d';

  /// 获取所有密钥
  static Future<List<Map<String, dynamic>>> getApiKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('获取密钥列表失败: $e');
      return [];
    }
  }

  /// 保存密钥列表
  static Future<bool> saveApiKeys(List<Map<String, dynamic>> keys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(keys);
      return await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('保存密钥列表失败: $e');
      return false;
    }
  }

  /// 添加单个密钥
  static Future<bool> addApiKey(Map<String, dynamic> keyData) async {
    try {
      // 验证必需字段
      if (!_validateKeyData(keyData)) {
        print('密钥数据验证失败');
        return false;
      }

      final keys = await getApiKeys();
      
      // 检查是否已存在相同的 BID
      final bid = keyData['bid'];
      if (keys.any((k) => k['bid'] == bid)) {
        print('密钥已存在: $bid');
        return false;
      }

      keys.add(keyData);
      return await saveApiKeys(keys);
    } catch (e) {
      print('添加密钥失败: $e');
      return false;
    }
  }

  /// 删除密钥
  static Future<bool> deleteApiKey(String bid) async {
    try {
      final keys = await getApiKeys();
      keys.removeWhere((k) => k['bid'] == bid);
      return await saveApiKeys(keys);
    } catch (e) {
      print('删除密钥失败: $e');
      return false;
    }
  }

  /// 更新密钥
  static Future<bool> updateApiKey(String bid, Map<String, dynamic> newData) async {
    try {
      if (!_validateKeyData(newData)) {
        print('密钥数据验证失败');
        return false;
      }

      final keys = await getApiKeys();
      final index = keys.indexWhere((k) => k['bid'] == bid);
      
      if (index == -1) {
        print('未找到密钥: $bid');
        return false;
      }

      keys[index] = newData;
      return await saveApiKeys(keys);
    } catch (e) {
      print('更新密钥失败: $e');
      return false;
    }
  }

  /// 验证密钥数据
  static bool _validateKeyData(Map<String, dynamic> data) {
    // 检查必需字段
    if (!data.containsKey('bid') || 
        !data.containsKey('key') || 
        !data.containsKey('name') ||
        !data.containsKey('intro') ||
        !data.containsKey('model')) {
      print('缺少必需字段');
      return false;
    }

    // 验证 model 字段
    if (data['model'] != _expectedModel) {
      print('model 字段不匹配，期望: $_expectedModel, 实际: ${data['model']}');
      return false;
    }

    // 验证 bid 格式（32位16进制）
    final bid = data['bid'] as String?;
    if (bid == null || !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(bid)) {
      print('BID 格式错误，应为32位16进制字符串');
      return false;
    }

    // 验证 key 是16进制字符串
    final key = data['key'] as String?;
    if (key == null || !RegExp(r'^[a-fA-F0-9]+$').hasMatch(key)) {
      print('Key 格式错误，应为16进制字符串');
      return false;
    }

    return true;
  }

  /// 清空所有密钥
  static Future<bool> clearAllKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_storageKey);
    } catch (e) {
      print('清空密钥失败: $e');
      return false;
    }
  }

  /// 获取密钥数量
  static Future<int> getKeysCount() async {
    final keys = await getApiKeys();
    return keys.length;
  }

  /// 根据 BID 查找密钥
  static Future<Map<String, dynamic>?> findKeyByBid(String bid) async {
    final keys = await getApiKeys();
    try {
      return keys.firstWhere((k) => k['bid'] == bid);
    } catch (e) {
      return null;
    }
  }
}
