import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha3.dart';
import 'package:exif/exif.dart';

import '../../../core/models/block_model.dart';
import '../../../core/network/api/block_api.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/utils/formatters/time_formatter.dart';
import '../../../core/utils/generators/bid_generator.dart';
import '../../../state/connection_provider.dart';

/// 文件上传服务，用于处理拖拽上传文件
class FileUploadService {
  static const String _fileModelId = 'c4238dd0d3d95db7b473adb449f6d282';

  final ConnectionProvider connectionProvider;

  FileUploadService({required this.connectionProvider});

  /// 上传文件并创建 Block
  Future<BlockModel> uploadFile({
    required File file,
    String? linkBid,
    String? nodeBid,
    bool encrypt = true,
  }) async {
    // 获取存储连接
    final storageConnection = connectionProvider.activeConnection;
    if (storageConnection == null) {
      throw Exception('当前没有可用的连接');
    }

    if (storageConnection.address.isEmpty) {
      throw Exception('IPFS 节点地址无效');
    }

    // 提取文件信息
    final fileInfo = await _extractFileInfo(file);

    // 上传文件到 IPFS
    final ipfsData = await _uploadToIpfs(
      file: file,
      endpoint: storageConnection.address,
      encrypt: encrypt,
      fileExtension: fileInfo.extension,
      uploadPassword: storageConnection.ipfsUploadPassword ?? '',
    );

    // 如果是图片，缓存预览
    final cid = ipfsData['cid'] as String?;
    if (cid != null && fileInfo.isImage && fileInfo.previewBytes != null) {
      await ImageCacheHelper.removeFromCache(cid);
      ImageCacheHelper.cacheMemoryImage(
        cid,
        fileInfo.previewBytes!,
        variant: ImageVariant.original,
      );
    }

    // 确定 node_bid：优先使用传入的 nodeBid，否则从 nodeData 中获取
    String blockNodeBid = '';
    if (nodeBid != null && nodeBid.isNotEmpty) {
      blockNodeBid = nodeBid;
    } else if (storageConnection.nodeData != null) {
      final bid = storageConnection.nodeData!['bid'];
      if (bid is String && bid.isNotEmpty) {
        blockNodeBid = bid;
      }
    }

    if (blockNodeBid.isEmpty || blockNodeBid.length < 10) {
      throw Exception('无效的节点 BID: $blockNodeBid');
    }

    // 构建基础 Block 数据 - 与 file_edit_page 初始化时相同
    final baseData = <String, dynamic>{
      'bid': '',
      'tag': <String>[],
      'link': <String>[],
      'permission_level': 0,
      'model': _fileModelId,
      'name': '',
      'intro': '',
      'ipfs': <String, dynamic>{},
      'node_bid': blockNodeBid,
    };

    // 使用与 file_edit_page 相同的方式构建最终数据
    final blockData = Map<String, dynamic>.from(baseData)
      ..['name'] = fileInfo.name
      ..['intro'] = ''
      ..['ipfs'] = ipfsData
      ..['bid'] = generateBidV2(blockNodeBid)
      ..['node_bid'] = blockNodeBid
      ..['model'] = _fileModelId
      ..['link'] = linkBid != null ? [linkBid] : <String>[]; // 只在 linkBid 不为 null 时添加

    if (fileInfo.timestamp != null) {
      blockData['add_time'] = iso8601WithOffset(fileInfo.timestamp!);
    }

    if (fileInfo.gps != null) {
      blockData['gps'] = fileInfo.gps;
    }

    // 保存 Block
    final api = BlockApi(connectionProvider: connectionProvider);
    await api.saveBlock(
      data: blockData,
      receiverBid: blockNodeBid,
    );

    return BlockModel(data: blockData);
  }

  /// 提取文件信息
  Future<_FileInfo> _extractFileInfo(File file) async {
    final fileName = file.path.split('/').last;
    final nameParts = fileName.split('.');
    final name = nameParts.length > 1
        ? nameParts.sublist(0, nameParts.length - 1).join('.')
        : fileName;
    final extension = nameParts.length > 1 ? '.${nameParts.last}' : '';

    final fileStat = await file.stat();
    final size = await file.length();
    final createdTime = fileStat.changed;
    final modifiedTime = fileStat.modified;
    DateTime? timestamp =
        createdTime.isBefore(modifiedTime) ? createdTime : modifiedTime;

    final bytes = await file.readAsBytes();
    Uint8List? previewBytes;
    Map<String, double>? gps;

    // 检查是否为图片
    final ext = extension.toLowerCase().replaceAll('.', '');
    final isImage = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'svg',
      'tiff',
      'tif'
    ].contains(ext);

    if (isImage) {
      previewBytes = bytes;

      // 提取 EXIF 信息
      if (['jpg', 'jpeg', 'tiff', 'tif'].contains(ext)) {
        try {
          final exifData = await readExifFromBytes(bytes);

          // 提取拍摄时间
          final dateTimeOriginal =
              exifData['EXIF DateTimeOriginal']?.toString();
          if (dateTimeOriginal != null) {
            final formattedString =
                dateTimeOriginal.replaceFirst(':', '-').replaceFirst(':', '-');
            final exifTimestamp = DateTime.tryParse(formattedString);
            if (exifTimestamp != null) {
              timestamp = exifTimestamp;
            }
          }

          // 提取 GPS 信息
          gps = _extractGpsCoordinates(exifData);
        } catch (e) {
          // 忽略 EXIF 提取错误
        }
      }
    }

    return _FileInfo(
      name: name,
      extension: extension,
      size: size,
      timestamp: timestamp,
      isImage: isImage,
      previewBytes: previewBytes,
      gps: gps,
    );
  }

  /// 提取 GPS 坐标
  Map<String, double>? _extractGpsCoordinates(
      Map<String, IfdTag> exifData) {
    try {
      final latRef = exifData['GPS GPSLatitudeRef']?.toString();
      final lonRef = exifData['GPS GPSLongitudeRef']?.toString();
      final latRatios = exifData['GPS GPSLatitude']?.values;
      final lonRatios = exifData['GPS GPSLongitude']?.values;

      if (latRef == null ||
          lonRef == null ||
          latRatios == null ||
          lonRatios == null) {
        return null;
      }

      final lat = _convertGpsCoordinate(latRatios, latRef);
      final lon = _convertGpsCoordinate(lonRatios, lonRef);

      if (lat == null || lon == null) return null;

      return {'latitude': lat, 'longitude': lon};
    } catch (e) {
      return null;
    }
  }

  /// 转换 GPS 坐标
  double? _convertGpsCoordinate(IfdValues values, String ref) {
    try {
      final ratios = values.toList();
      if (ratios.length < 3) return null;

      final degrees = (ratios[0] as Ratio).numerator / (ratios[0] as Ratio).denominator;
      final minutes = (ratios[1] as Ratio).numerator / (ratios[1] as Ratio).denominator;
      final seconds = (ratios[2] as Ratio).numerator / (ratios[2] as Ratio).denominator;

      var coordinate = degrees + (minutes / 60.0) + (seconds / 3600.0);

      if (ref == 'S' || ref == 'W') {
        coordinate = -coordinate;
      }

      return coordinate;
    } catch (e) {
      return null;
    }
  }

  /// 上传文件到 IPFS
  Future<Map<String, dynamic>> _uploadToIpfs({
    required File file,
    required String endpoint,
    required bool encrypt,
    required String fileExtension,
    required String uploadPassword,
  }) async {
    final manager = _UploadTaskManager(
      sourceFile: file,
      endpoint: endpoint,
      encrypt: encrypt,
      fileExtension: fileExtension,
      uploadPassword: uploadPassword,
    );

    try {
      return await manager.execute();
    } finally {
      await manager.dispose();
    }
  }
}

/// 文件信息
class _FileInfo {
  final String name;
  final String extension;
  final int size;
  final DateTime? timestamp;
  final bool isImage;
  final Uint8List? previewBytes;
  final Map<String, double>? gps;

  _FileInfo({
    required this.name,
    required this.extension,
    required this.size,
    this.timestamp,
    required this.isImage,
    this.previewBytes,
    this.gps,
  });
}

/// 上传任务管理器
class _UploadTaskManager {
  final File sourceFile;
  final String endpoint;
  final bool encrypt;
  final String fileExtension;
  final String uploadPassword;

  final List<String> _generatedTempFiles = [];
  String? _tempDirectoryPath;

  _UploadTaskManager({
    required this.sourceFile,
    required this.endpoint,
    required this.encrypt,
    required this.fileExtension,
    required this.uploadPassword,
  });

  Future<Map<String, dynamic>> execute() async {
    _tempDirectoryPath ??= (await getTemporaryDirectory()).path;

    final payload = _UploadTaskPayload(
      sourcePath: sourceFile.path,
      encrypt: encrypt,
      tempDirPath: _tempDirectoryPath!,
    );

    final result = await Isolate.run(() => _performTask(payload));

    if (result.generatedTempPath != null) {
      _generatedTempFiles.add(result.generatedTempPath!);
    }

    final cid = await _uploadToIpfsEndpoint(result.uploadPath);

    final response = <String, dynamic>{
      'cid': cid,
      'ext': fileExtension.startsWith('.') ? fileExtension : '.$fileExtension',
      'size': result.fileSize,
      'sha3_256': result.sha3Hex,
    };

    if (result.encryptionKeyHex != null) {
      response['encryption'] = {
        'algo': 'PPE-001',
        'key': result.encryptionKeyHex,
      };
    }

    return response;
  }

  Future<void> dispose() async {
    for (final path in _generatedTempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // 忽略清理错误
      }
    }
    _generatedTempFiles.clear();
  }

  Future<String> _uploadToIpfsEndpoint(String uploadPath) async {
    final endpointUrl = Uri.parse(endpoint);
    final uploadUrl = endpointUrl.replace(path: '/ipfs/ipfs/upload');

    final request = http.MultipartRequest('POST', uploadUrl)
      ..fields['password'] = uploadPassword
      ..files.add(await http.MultipartFile.fromPath('file', uploadPath));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('上传失败(${response.statusCode})：$body');
    }

    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final cid = decoded['cid'];
      if (cid is String && cid.isNotEmpty) {
        return cid;
      }
      throw Exception('上传响应缺少 cid 字段');
    } catch (error) {
      throw Exception('解析上传响应失败：$error');
    }
  }

  static Future<_UploadTaskResult> _performTask(
      _UploadTaskPayload payload) async {
    final sourceFile = File(payload.sourcePath);
    final bytes = await sourceFile.readAsBytes();

    if (!payload.encrypt) {
      return _UploadTaskResult(
        uploadPath: payload.sourcePath,
        fileSize: bytes.length,
        sha3Hex: _sha3Hex(bytes),
      );
    }

    final key = _randomBytes(32);
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKeyFromBytes(key);
    final nonce = algorithm.newNonce();

    final secretBox = await algorithm.encrypt(
      bytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final combined = Uint8List.fromList([
      ...nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ]);

    final tempPath = '${payload.tempDirPath}/encrypted_${DateTime.now().millisecondsSinceEpoch}.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(combined);

    return _UploadTaskResult(
      uploadPath: tempPath,
      fileSize: bytes.length,
      sha3Hex: _sha3Hex(bytes),
      encryptionKeyHex: _bytesToHex(key),
      generatedTempPath: tempPath,
    );
  }

  static String _sha3Hex(Uint8List data) {
    final digest = SHA3Digest(256);
    final hash = digest.process(data);
    return _bytesToHex(hash);
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => random.nextInt(256)));
  }
}

class _UploadTaskPayload {
  final String sourcePath;
  final bool encrypt;
  final String tempDirPath;

  _UploadTaskPayload({
    required this.sourcePath,
    required this.encrypt,
    required this.tempDirPath,
  });
}

class _UploadTaskResult {
  final String uploadPath;
  final int fileSize;
  final String sha3Hex;
  final String? encryptionKeyHex;
  final String? generatedTempPath;

  _UploadTaskResult({
    required this.uploadPath,
    required this.fileSize,
    required this.sha3Hex,
    this.encryptionKeyHex,
    this.generatedTempPath,
  });
}
