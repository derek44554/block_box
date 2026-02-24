import 'dart:convert';
import 'package:block_app/core/network/crypto/crypto_util.dart';
import '../../../core/models/block_model.dart';
import '../../../features/settings/services/api_keys_manager.dart';


class DecryptionResult {
  final Map<String, dynamic> data;
  final String keyBid;

  DecryptionResult(this.data, this.keyBid);
}

/// 服务解密工具类
class ServiceDecryptor {
  /// 尝试解密服务块
  /// 如果块包含 crypto 字段，会尝试使用本地密钥解密
  /// 返回解密后的数据，如果解密失败或不需要解密则返回 null
  static Future<DecryptionResult?> tryDecrypt(BlockModel block) async {
    // 检查是否包含 crypto 字段
    final crypto = block.get<Map<String, dynamic>>('crypto');
    if (crypto == null) {
      return null; // 不是加密的块
    }

    try {
      // 获取加密的密钥列表
      final keys = crypto['keys'];
      if (keys is! List || keys.isEmpty) {
        print('加密块没有密钥信息');
        return null;
      }

      // 获取加密的文本
      final encryptedText = crypto['text'] as String?;
      if (encryptedText == null || encryptedText.isEmpty) {
        print('加密块没有加密文本');
        return null;
      }

      // 获取本地所有密钥
      final localKeys = await ApiKeysManager.getApiKeys();
      if (localKeys.isEmpty) {
        print('本地没有可用的密钥');
        return null;
      }

      // 尝试匹配密钥并解密
      for (final encryptedKey in keys) {
        if (encryptedKey is! Map<String, dynamic>) continue;

        final keyBid = encryptedKey['bid'] as String?;
        final encryptedDataKey = encryptedKey['key'] as String?;

        if (keyBid == null || encryptedDataKey == null) continue;

        // 查找匹配的本地密钥
        final matchedKey = localKeys.firstWhere(
          (k) => k['bid'] == keyBid,
          orElse: () => <String, dynamic>{},
        );

        if (matchedKey.isEmpty) continue;

        try {
          // 获取本地密钥（十六进制格式）
          final localKeyHex = matchedKey['key'] as String;
          final localKeyBytes = CryptoUtil.hexToBytes(localKeyHex);

          // 解密数据密钥
          final dataKeyBytes = CryptoUtil.decryptAesGcm(encryptedDataKey, localKeyBytes);

          // 使用数据密钥解密实际数据
          final decryptedBytes = CryptoUtil.decryptAesGcm(encryptedText, dataKeyBytes);
          final decryptedJson = utf8.decode(decryptedBytes);

          // 解析 JSON
          final decryptedData = json.decode(decryptedJson) as Map<String, dynamic>;

          print('成功解密服务数据，使用密钥: ${matchedKey['name']}');
          return DecryptionResult(decryptedData, keyBid);
        } catch (e) {
          print('使用密钥 $keyBid 解密失败: $e');
          continue; // 尝试下一个密钥
        }
      }

      print('所有密钥都无法解密此服务');
      return null;
    } catch (e) {
      print('解密过程出错: $e');
      return null;
    }
  }

  /// 检查块是否已加密
  static bool isEncrypted(BlockModel block) {
    return block.get<Map<String, dynamic>>('crypto') != null;
  }

  /// 获取公开信息（加密块的 public 字段）
  static String? getPublicInfo(BlockModel block) {
    if (!isEncrypted(block)) return null;
    return block.maybeString('public');
  }
}
