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

      if (kDebugMode) {
        final previewLength = encryptedText.length > 50 ? 50 : encryptedText.length;
        debugPrint('BridgeTransport: Received encrypted response');
        debugPrint('  Original: length=${encryptedText.length}, value=${encryptedText.substring(0, previewLength)}...');
        debugPrint('  Normalized: length=${normalizedBase64.length}');
      }

      // 使用相同的密钥解密响应数据
      String decryptedText;
      try {
        decryptedText = CryptoUtil.decryptBase64(normalizedBase64, connection.keyBase64);
      } catch (error) {
        if (kDebugMode) {
          final previewLength = normalizedBase64.length > 50 ? 50 : normalizedBase64.length;
          debugPrint('BridgeTransport: Decryption failed');
          debugPrint('  Base64 length: ${normalizedBase64.length}');
          debugPrint('  Base64 preview: ${normalizedBase64.substring(0, previewLength)}...');
          debugPrint('  Error: $error');
        }
        rethrow;
      }

      if (kDebugMode) {
        debugPrint('BridgeTransport: Decrypted response: $decryptedText');
      }

      // 解析解密后的JSON数据
      return jsonDecode(decryptedText) as Map<String, dynamic>;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('BridgeTransport error: $error');
        debugPrint('$stackTrace');
      }
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
