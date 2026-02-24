import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../blocks/file/models/file_card_data.dart';
import '../core/storage/cache/image_cache.dart';

class IpfsFileHelper {
  IpfsFileHelper._();

  static String? buildUrl({required String endpoint, required String cid, String? extension}) {
    final trimmedEndpoint = endpoint.trim().replaceAll(RegExp(r'/+ ?$'), '');
    if (trimmedEndpoint.isEmpty) {
      return null;
    }
    final normalizedCid = cid.trim();
    if (normalizedCid.isEmpty) {
      return null;
    }
    return '$trimmedEndpoint/$normalizedCid';
  }

  /// Downloads the original image from the network without checking or updating caches.
  /// 
  /// This method assumes the caller (BlockImageLoader) has already checked caches.
  /// Returns the original (full-size) image bytes after decryption if needed.
  /// 
  /// Throws [StateError] if CID is missing or endpoint cannot build a valid URL.
  /// Throws [Exception] for network failures after retry attempts.
  static Future<Uint8List> downloadFromNetwork({
    required String endpoint,
    required FileCardData data,
  }) async {
    final cid = data.cid;
    if (cid == null || cid.isEmpty) {
      throw StateError('CID is missing');
    }

    final url = buildUrl(endpoint: endpoint, cid: cid);
    if (url == null) {
      throw StateError('Could not build IPFS URL from endpoint and CID');
    }

    final uri = Uri.parse(url);
    try {
      final responseBytes = await _fetchBytesWithRetry(uri);

      Uint8List fileBytes = responseBytes;
      final encryption = data.encryption;

      if (encryption != null && encryption.isSupported) {
        fileBytes = await Isolate.run(
          () => _decryptAesGcm(fileBytes, encryption.keyBase64),
        );
      }

      return fileBytes;
    } catch (e, stack) {
      debugPrint('[IPFS] Error downloading $cid : $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// @deprecated Use downloadFromNetwork instead. This method will be removed in a future version.
  /// 
  /// Legacy method that downloads from network without cache checking.
  /// Kept temporarily for backward compatibility during refactoring.
  static Future<Uint8List> loadByCid({
    required String endpoint,
    required FileCardData data,
    ImageVariant variant = ImageVariant.medium,
    bool fetchOriginalIfMissing = true,
  }) async {
    // Simply delegate to downloadFromNetwork - cache logic removed
    return downloadFromNetwork(endpoint: endpoint, data: data);
  }

  /// 直接获取原始文件字节，不进行缩略图生成与图片缓存。
  static Future<Uint8List> loadRawByCid({
    required String endpoint,
    required FileCardData data,
  }) async {
    final cid = data.cid;
    if (cid == null || cid.isEmpty) {
      throw Exception('CID is missing');
    }

    final url = buildUrl(endpoint: endpoint, cid: cid);
    if (url == null) {
      throw Exception('Could not build IPFS URL from endpoint and CID');
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to load file from IPFS: ${response.statusCode}');
      }

      final encryption = data.encryption;
      if (encryption != null && encryption.isSupported) {
        final decrypted = await Isolate.run(
          () => _decryptAesGcm(response.bodyBytes, encryption.keyBase64),
        );
        return decrypted;
      }

      return response.bodyBytes;
    } catch (error, stack) {
      debugPrint('[IPFS] Error loading raw $cid : $error');
      debugPrint(stack.toString());
      rethrow;
    }
  }



  static Future<Uint8List> _fetchBytesWithRetry(
    Uri uri, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 250),
  }) async {
    Exception? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12)
        ..idleTimeout = const Duration(seconds: 12)
        ..autoUncompress = true;

      try {
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        request.headers.set(HttpHeaders.userAgentHeader, 'block_app/1.0');

        final response = await request.close();
        if (response.statusCode != 200) {
          lastError = HttpException('Failed to load file from IPFS: ${response.statusCode}', uri: uri);
        } else {
          final bytes = await consolidateHttpClientResponseBytes(response);
          return bytes;
        }
      } on SocketException catch (error, stack) {
        lastError = error;
      } on HttpException catch (error, stack) {
        lastError = error;
      } on Exception catch (error, stack) {
        lastError = error;
      } finally {
        client.close(force: true);
      }

      if (attempt < maxAttempts - 1) {
        final delay = initialDelay * (attempt + 1);
        await Future.delayed(delay);
      }
    }

    throw Exception('Failed to load file from IPFS after $maxAttempts attempts: $lastError');
  }

  static Future<Uint8List> _decryptAesGcm(Uint8List encryptedBytes, String keyValue) async {
    if (encryptedBytes.length < 32) {
      throw Exception('Encrypted payload is too short');
    }

    final keyBytes = _decodeKey(keyValue);
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKeyFromBytes(keyBytes);

    final strategies = <_PayloadStrategy>[
      const _PayloadStrategy(nonceLength: 12, macAtEnd: false),
      const _PayloadStrategy(nonceLength: 12, macAtEnd: true),
      const _PayloadStrategy(nonceLength: 16, macAtEnd: false),
      const _PayloadStrategy(nonceLength: 16, macAtEnd: true),
    ];

    for (final strategy in strategies) {
      try {
        final secretBox = _buildSecretBox(encryptedBytes, strategy);
        final decrypted = await algorithm.decrypt(secretBox, secretKey: secretKey);
        return Uint8List.fromList(decrypted);
      } on SecretBoxAuthenticationError {
        continue;
      } catch (error) {
        continue;
      }
    }

    throw Exception('Unsupported encrypted payload format');
  }

  static Uint8List _decodeKey(String value) {
    final normalized = value.trim();
    final isHex = RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized) && normalized.length.isEven;

    if (isHex) {
      final decoded = _decodeHex(normalized);
      return decoded;
    }

    try {
      final decoded = base64Decode(normalized);
      return decoded;
    } on FormatException {
      final decoded = _decodeHex(normalized);
      return decoded;
    }
  }

  static Uint8List _decodeHex(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (cleaned.length.isOdd) {
      throw FormatException('Invalid hex string length');
    }
    final result = Uint8List(cleaned.length ~/ 2);
    for (var i = 0; i < cleaned.length; i += 2) {
      result[i ~/ 2] = int.parse(cleaned.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static SecretBox _buildSecretBox(Uint8List data, _PayloadStrategy strategy) {
    if (data.length <= strategy.nonceLength + 16) {
      throw Exception('Encrypted payload format mismatch');
    }

    final nonce = data.sublist(0, strategy.nonceLength);
    late Uint8List macBytes;
    late Uint8List cipherBytes;

    if (strategy.macAtEnd) {
      macBytes = data.sublist(data.length - 16);
      cipherBytes = data.sublist(strategy.nonceLength, data.length - 16);
    } else {
      macBytes = data.sublist(strategy.nonceLength, strategy.nonceLength + 16);
      cipherBytes = data.sublist(strategy.nonceLength + 16);
    }

    return SecretBox(cipherBytes, nonce: nonce, mac: Mac(macBytes));
  }
}

class _PayloadStrategy {
  const _PayloadStrategy({required this.nonceLength, required this.macAtEnd});

  final int nonceLength;
  final bool macAtEnd;
}
