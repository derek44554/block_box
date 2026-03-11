import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/digests/sha3.dart';

/// Helper for computing IPFS upload password from node key
class IpfsPasswordHelper {
  /// Compute IPFS upload password using SHA-3 256 hash of (nodeKey + "IPFS")
  /// 
  /// The password is computed as: SHA3-256(nodeKeyBase64 + "IPFS")
  static String computeUploadPassword(String nodeKeyBase64) {
    if (nodeKeyBase64.isEmpty) {
      return '';
    }
    
    // Concatenate node key with "IPFS" string
    final input = nodeKeyBase64 + 'IPFS';
    final inputBytes = utf8.encode(input);
    
    // Compute SHA-3 256 hash
    final digest = SHA3Digest(256);
    final hash = digest.process(Uint8List.fromList(inputBytes));
    
    // Convert to hex string
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
