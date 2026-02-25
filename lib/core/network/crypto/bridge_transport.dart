import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:block_app/core/network/models/connection_model.dart';
import 'package:block_app/core/network/crypto/crypto_util.dart';

class BridgeTransport {
  static Future<Map<String, dynamic>> post({
    required ConnectionModel connection,
    required Map<String, dynamic> payload,
  }) async {
    final Uri uri = Uri.parse('${connection.address}/bridge/ins');
    final encryptedBody = CryptoUtil.encryptBase64(jsonEncode(payload), connection.keyBase64);

    try {
      final response = await http.post(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({'text': encryptedBody}),
      );

      if (response.statusCode != 200) {
        throw HttpException('Request failed with status ${response.statusCode}', uri: uri);
      }

      // 解析响应体，获取加密的 text 字段
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final encryptedText = responseJson['text'] as String?;

      if (encryptedText == null || encryptedText.isEmpty) {
        throw HttpException('Response missing encrypted text field', uri: uri);
      }

      // 清理并规范化 Base64 字符串（去除空白字符，处理填充）
      final normalizedBase64 = CryptoUtil.normalizeBase64(encryptedText);

      // 使用相同的密钥解密响应数据
      String decryptedText;
      try {
        decryptedText = CryptoUtil.decryptBase64(normalizedBase64, connection.keyBase64);
      } catch (error) {
        rethrow;
      }

      // 解析解密后的JSON数据
      return jsonDecode(decryptedText) as Map<String, dynamic>;
    } catch (error, stackTrace) {
      rethrow;
    }
  }
}

class HttpException implements Exception {
  HttpException(this.message, {this.uri});

  final String message;
  final Uri? uri;

  @override
  String toString() {
    if (uri == null) {
      return message;
    }
    return '$message, uri=$uri';
  }
}
