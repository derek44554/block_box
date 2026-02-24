import 'dart:typed_data';

import 'package:block_app/core/models/block_model.dart';

import '../../../core/storage/cache/image_cache.dart';


class PhotoImage {
  PhotoImage({
    required this.block,
    required this.heroTag,
    required this.title,
    required this.time,
    this.previewBytes,
    this.previewVariant,
    this.isSupportedImage = true,
  });

  final BlockModel block;
  final String heroTag;
  final String title;
  final String time;
  final bool isSupportedImage;
  Uint8List? previewBytes;
  ImageVariant? previewVariant;

  String get cid => block.map('ipfs')['cid'] as String? ?? '';
  String get bid => block.maybeString('bid') ?? '';
}

class PhotoCollection {
  PhotoCollection({
    required this.bid,
    required Map<String, dynamic> block,
    this.isAlbum = false,
  }) : _block = Map.unmodifiable(Map<String, dynamic>.from(block));

  PhotoCollection._internal({
    required this.bid,
    required Map<String, dynamic> block,
    required this.isAlbum,
  }) : _block = Map.unmodifiable(block);

  final String bid;
  final Map<String, dynamic> _block;
  final bool isAlbum;

  String? get title => (_block['name'] as String?)?.trim();

  String? get intro {
    final intro = (_block['intro'] as String?)?.trim();
    if (intro != null && intro.isNotEmpty) {
      return intro;
    }
    return (_block['description'] as String?)?.trim();
  }

  Map<String, dynamic> get block => Map<String, dynamic>.from(_block);

  Map<String, dynamic> toJson() => {
    'bid': bid,
    'block': _block,
    'isAlbum': isAlbum,
  };

  PhotoCollection copyWith({
    String? bid,
    Map<String, dynamic>? block,
    bool? isAlbum,
  }) {
    final updatedBlock = block != null
        ? Map<String, dynamic>.from(block)
        : Map<String, dynamic>.from(_block);
    return PhotoCollection._internal(
      bid: bid ?? this.bid,
      block: updatedBlock,
      isAlbum: isAlbum ?? this.isAlbum,
    );
  }

  factory PhotoCollection.fromJson(Map<String, dynamic> json) {
    final rawBlock = json['block'];
    Map<String, dynamic> blockMap;

    if (rawBlock is Map<String, dynamic> && rawBlock.isNotEmpty) {
      blockMap = Map<String, dynamic>.from(rawBlock);
    } else {
      blockMap = <String, dynamic>{};
      final legacyTitle = json['title'];
      final legacyIntro = json['intro'] ?? json['description'];
      if (legacyTitle != null) {
        blockMap['name'] = legacyTitle;
      }
      if (legacyIntro != null) {
        blockMap['intro'] = legacyIntro;
      }
    }

    final resolvedBid =
        (json['bid'] as String?) ?? (blockMap['bid'] as String?) ?? '';
    if (blockMap['bid'] == null && resolvedBid.isNotEmpty) {
      blockMap['bid'] = resolvedBid;
    }

    return PhotoCollection._internal(
      bid: resolvedBid,
      block: Map<String, dynamic>.from(blockMap),
      isAlbum: json['isAlbum'] as bool? ?? false,
    );
  }
}
