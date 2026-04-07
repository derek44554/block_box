import '../../../core/models/block_model.dart';

/// 音频文件数据模型，用于 block 级别的音频播放
class AudioItem {
  AudioItem({required this.block});

  final BlockModel block;

  String get bid => block.maybeString('bid') ?? '';
  String get audioCid => block.map('ipfs')['cid'] as String? ?? '';

  factory AudioItem.fromBlock(BlockModel block) => AudioItem(block: block);
}
