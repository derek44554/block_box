import 'package:block_app/core/models/block_model.dart';
import 'package:flutter/foundation.dart';

/// 音乐项数据模型
class MusicItem {
  MusicItem({
    required this.block,
    required this.title,
    this.artist,
    this.duration,
    this.coverCid,
  });

  final BlockModel block;
  final String title;
  final String? artist;
  final Duration? duration;
  final String? coverCid;

  String get bid => block.maybeString('bid') ?? '';
  String get audioCid => block.map('ipfs')['cid'] as String? ?? '';
  
  /// 从 BlockModel 构建 MusicItem
  factory MusicItem.fromBlock(BlockModel block) {
    final title = block.maybeString('name') ?? 
                  block.maybeString('fileName') ?? 
                  '未知音乐';
    final artist = block.maybeString('artist') ?? block.maybeString('author');
    
    // 尝试从 metadata 中获取时长
    Duration? duration;
    final metadata = block.map('metadata');
    final durationValue = metadata['duration'];
    
    if (durationValue is num) {
      // 如果 duration 大于 10000，很可能是毫秒单位
      if (durationValue > 10000) {
        duration = Duration(milliseconds: durationValue.toInt());
      } else {
        duration = Duration(seconds: durationValue.toInt());
      }
    }
    
    final coverCid = block.maybeString('cover');
    
    return MusicItem(
      block: block,
      title: title,
      artist: artist,
      duration: duration,
      coverCid: coverCid,
    );
  }
}

/// 音乐集合数据模型
class MusicCollection {
  MusicCollection({
    required this.bid,
    required Map<String, dynamic> block,
    this.isPlaylist = false,
  }) : _block = Map.unmodifiable(Map<String, dynamic>.from(block));

  MusicCollection._internal({
    required this.bid,
    required Map<String, dynamic> block,
    required this.isPlaylist,
  }) : _block = Map.unmodifiable(block);

  final String bid;
  final Map<String, dynamic> _block;
  final bool isPlaylist;

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
    'isPlaylist': isPlaylist,
  };

  MusicCollection copyWith({
    String? bid,
    Map<String, dynamic>? block,
    bool? isPlaylist,
  }) {
    final updatedBlock = block != null
        ? Map<String, dynamic>.from(block)
        : Map<String, dynamic>.from(_block);
    return MusicCollection._internal(
      bid: bid ?? this.bid,
      block: updatedBlock,
      isPlaylist: isPlaylist ?? this.isPlaylist,
    );
  }

  factory MusicCollection.fromJson(Map<String, dynamic> json) {
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

    return MusicCollection._internal(
      bid: resolvedBid,
      block: Map<String, dynamic>.from(blockMap),
      isPlaylist: json['isPlaylist'] as bool? ?? false,
    );
  }
}

