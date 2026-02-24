
import '../../../core/models/block_model.dart';

class FileCardData {
  const FileCardData({
    required this.fileName,
    required this.bid,
    required this.createdAt,
    this.intro,
    this.cid,
    this.ipfsExt,
    this.ipfsSize,
    this.ipfsSha3,
    this.encryption,
    this.gps,
  });

  factory FileCardData.fromBlock(BlockModel block) {
    final fileName = block.maybeString('name') ?? block.maybeString('fileName') ?? '未命名文件';
    final bid = block.maybeString('bid') ?? '';
    final intro = block.maybeString('intro');
    final createdAt = block.getDateTime('add_time') ?? block.getDateTime('createdAt') ?? DateTime.now();
    final ipfs = block.map('ipfs');
    final gpsMap = block.map('gps');

    final cid = ipfs['cid'] as String?;
    final ext = ipfs['ext'] as String?;
    final size = (ipfs['size'] is num) ? (ipfs['size'] as num).toInt() : null;
    final sha3 = ipfs['sha3_256'] as String?;
    final encryptionMap = ipfs['encryption'];

    FileEncryptionInfo? encryptionInfo;
    if (encryptionMap is Map<String, dynamic>) {
      final algo = encryptionMap['algo'] as String?;
      final key = encryptionMap['key'] as String?;
      if (algo != null && key != null) {
        encryptionInfo = FileEncryptionInfo(algo: algo, keyBase64: key);
      }
    }

    GpsCoordinates? gps;
    if (gpsMap.containsKey('latitude') && gpsMap.containsKey('longitude')) {
      final lat = (gpsMap['latitude'] as num?)?.toDouble();
      final lon = (gpsMap['longitude'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        gps = GpsCoordinates(latitude: lat, longitude: lon);
      }
    }

    return FileCardData(
      fileName: fileName,
      bid: bid,
      createdAt: createdAt,
      intro: intro,
      cid: cid,
      ipfsExt: ext,
      ipfsSize: size,
      ipfsSha3: sha3,
      encryption: encryptionInfo,
      gps: gps,
    );
  }

  final String fileName;
  final String bid;
  final DateTime createdAt;
  final String? intro;
  final String? cid;
  final String? ipfsExt;
  final int? ipfsSize;
  final String? ipfsSha3;
  final FileEncryptionInfo? encryption;
  final GpsCoordinates? gps;

  String get extension {
    if (ipfsExt != null && ipfsExt!.isNotEmpty) {
      final raw = ipfsExt!.trim().toLowerCase();
      if (raw.isEmpty) {
        return '';
      }
      final slashIndex = raw.lastIndexOf('/');
      final dotIndex = raw.lastIndexOf('.');
      final splitIndex = slashIndex > dotIndex ? slashIndex : dotIndex;
      if (splitIndex != -1 && splitIndex + 1 < raw.length) {
        return raw.substring(splitIndex + 1);
      }
      return raw;
    }
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return '';
    return fileName.substring(lastDot + 1).toLowerCase();
  }

  String get nameWithoutExtension {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
  }
}

class FileEncryptionInfo {
  const FileEncryptionInfo({required this.algo, required this.keyBase64});

  final String algo;
  final String keyBase64;

  bool get isSupported => algo == 'PPE-001';
}

class GpsCoordinates {
  const GpsCoordinates({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}
