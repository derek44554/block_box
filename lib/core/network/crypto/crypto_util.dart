import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';


import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/block/modes/gcm.dart';

class CryptoUtil {
  /// Encrypts [plainText] using AES-CBC with PKCS7 padding. Returns Base64(iv + ciphertext).
  static String encryptBase64(String plainText, String base64Key) {
    final normalizedKey = normalizeBase64(base64Key);
    final keyBytes = Uint8List.fromList(base64Decode(normalizedKey));
    _assertValidKeyLength(keyBytes.length);

    final iv = _generateRandomBytes(16);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, pc.ParametersWithIV<pc.KeyParameter>(pc.KeyParameter(keyBytes), iv));

    final input = Uint8List.fromList(utf8.encode(plainText));
    final padded = _pkcs7Pad(input, cipher.blockSize);
    final encrypted = _processBlocks(cipher, padded);

    final combined = Uint8List(iv.length + encrypted.length)
      ..setAll(0, iv)
      ..setAll(iv.length, encrypted);
    return base64Encode(combined);
  }

  /// Decrypts a Base64(iv + ciphertext) payload using AES-CBC with PKCS7 padding.
  static String decryptBase64(String base64Payload, String base64Key) {
    final normalizedKey = normalizeBase64(base64Key);
    final keyBytes = Uint8List.fromList(base64Decode(normalizedKey));
    _assertValidKeyLength(keyBytes.length);

    final normalizedPayload = normalizeBase64(base64Payload);
    final payloadBytes = Uint8List.fromList(base64Decode(normalizedPayload));
    if (payloadBytes.length < 17) {
      throw ArgumentError('Payload too short to contain IV and ciphertext.');
    }

    final iv = payloadBytes.sublist(0, 16);
    final ciphertext = payloadBytes.sublist(16);

    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, pc.ParametersWithIV<pc.KeyParameter>(pc.KeyParameter(keyBytes), iv));

    final decryptedPadded = _processBlocks(cipher, ciphertext);
    final unpadded = _pkcs7Unpad(decryptedPadded, cipher.blockSize);
    return utf8.decode(unpadded);
  }

  static Uint8List _processBlocks(pc.BlockCipher cipher, Uint8List input) {
    final output = Uint8List(input.length);
    for (var offset = 0; offset < input.length; offset += cipher.blockSize) {
      cipher.processBlock(input, offset, output, offset);
    }
    return output;
  }

  static Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLength)
      ..setRange(0, data.length, data)
      ..fillRange(data.length, data.length + padLength, padLength);
    return padded;
  }

  static Uint8List _pkcs7Unpad(Uint8List data, int blockSize) {
    if (data.isEmpty || data.length % blockSize != 0) {
      throw ArgumentError('Invalid padded data length.');
    }
    final padLength = data.last;
    if (padLength <= 0 || padLength > blockSize) {
      throw ArgumentError('Invalid PKCS7 padding length.');
    }
    for (var i = 0; i < padLength; i++) {
      if (data[data.length - 1 - i] != padLength) {
        throw ArgumentError('Invalid PKCS7 padding.');
      }
    }
    return data.sublist(0, data.length - padLength);
  }

  static Uint8List _generateRandomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  static void _assertValidKeyLength(int length) {
    if (length != 16 && length != 24 && length != 32) {
      throw ArgumentError('Key length must be 16, 24, or 32 bytes.');
    }
  }

  /// 规范化 Base64 字符串：去除空白字符，并确保长度是4的倍数（自动补齐填充字符）。
  static String normalizeBase64(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), '');
    final remainder = cleaned.length % 4;
    if (remainder == 0) {
      return cleaned;
    }
    final paddingCount = 4 - remainder;
    final padding = List<String>.filled(paddingCount, '=').join();
    return cleaned + padding;
  }

  /// Generates a random key of [length] bytes.
  static Uint8List generateRandomKey(int length) {
    return _generateRandomBytes(length);
  }

  /// Encrypts [data] using AES-GCM with [key].
  /// Returns a hex string containing the nonce (16 bytes) followed by the ciphertext (including tag).
  static String encryptAesGcm(Uint8List data, Uint8List key) {
    _assertValidKeyLength(key.length);

    final nonce = _generateRandomBytes(16); // 128-bit nonce
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, pc.AEADParameters(pc.KeyParameter(key), 128, nonce, Uint8List(0)));

    final encrypted = _processAEADBlocks(cipher, data);

    final combined = Uint8List(nonce.length + encrypted.length)
      ..setAll(0, nonce)
      ..setAll(nonce.length, encrypted);

    return _bytesToHex(combined);
  }

  static Uint8List _processAEADBlocks(pc.AEADBlockCipher cipher, Uint8List input) {
    // GCM adds a 16-byte authentication tag
    final output = Uint8List(input.length + 16);
    final len = cipher.processBytes(input, 0, input.length, output, 0);
    final finalLen = cipher.doFinal(output, len);
    return output.sublist(0, len + finalLen);
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw ArgumentError('Invalid hex string length');
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  /// Decrypts [hexData] using AES-GCM with [key].
  /// [hexData] should contain the nonce (16 bytes) followed by the ciphertext (including tag).
  static Uint8List decryptAesGcm(String hexData, Uint8List key) {
    _assertValidKeyLength(key.length);

    final combined = hexToBytes(hexData);
    if (combined.length < 33) {
      // At least 16 bytes nonce + 16 bytes tag + 1 byte data
      throw ArgumentError('Encrypted data too short');
    }

    final nonce = combined.sublist(0, 16);
    final ciphertext = combined.sublist(16);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, pc.AEADParameters(pc.KeyParameter(key), 128, nonce, Uint8List(0)));

    final output = Uint8List(ciphertext.length);
    final len = cipher.processBytes(ciphertext, 0, ciphertext.length, output, 0);
    final finalLen = cipher.doFinal(output, len);
    
    return output.sublist(0, len + finalLen);
  }
}
