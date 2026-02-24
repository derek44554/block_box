import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/block_model.dart';
import '../../../core/storage/cache/image_cache.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/utils/formatters/file_size_formatter.dart';
import '../../common/block_detail_page.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/block_image_loader.dart';
import '../../../utils/file_category.dart';
import '../models/file_card_data.dart';
import '../../../features/music/models/music_models.dart';
import '../../../features/music/services/audio_player_service.dart';
import '../../../state/block_detail_listener_mixin.dart';


class FileDetailPage extends StatefulWidget {
  const FileDetailPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<FileDetailPage> createState() => _FileDetailPageState();
}

class _FileDetailPageState extends State<FileDetailPage> with BlockDetailListenerMixin {
  late FileCardData _data;
  Uint8List? _imageBytes;
  bool _isLoadingImage = false;
  String? _imageError;
  
  // 音频播放相关
  AudioPlayerService? _audioPlayer;
  bool _isAudioFile = false;
  MusicItem? _musicItem;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _data = FileCardData.fromBlock(updatedBlock);
      // Reset image loading state if file changed
      _imageBytes = null;
      _isLoadingImage = false;
      _imageError = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _data = FileCardData.fromBlock(widget.block);
    startBlockProviderListener();
    _checkIfAudioFile();
  }

  @override
  void dispose() {
    _audioPlayer?.removeListener(_onAudioStateChanged);
    _audioPlayer?.dispose();
    stopBlockProviderListener();
    super.dispose();
  }
  
  void _checkIfAudioFile() {
    final category = resolveFileCategory(_extension);
    _isAudioFile = category.isAudio;
    
    if (_isAudioFile) {
      _audioPlayer = AudioPlayerService();
      _audioPlayer!.addListener(_onAudioStateChanged);
      _musicItem = MusicItem.fromBlock(widget.block);
    }
  }
  
  void _onAudioStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _data.fileName;
    final intro = _data.intro;
    final bid = _data.bid;
    final createdAt = _data.createdAt;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      body: Container(
        color: Colors.black,
        child: RefreshIndicator(
          onRefresh: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlockDetailPage(block: widget.block),
              ),
            );
          },
          color: Colors.white,
          backgroundColor: Colors.grey.shade900,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    const SizedBox(height: 48),
                    _buildPreview(),
                    if (_isAudioFile) _buildAudioPlayer(),
                    _buildFileInfo(createdAt),
                    if (fileName.isNotEmpty) _buildTitle(fileName),
                    if (intro != null && intro.isNotEmpty) _buildIntro(intro),
                    if (bid.isNotEmpty) _buildBid(bid),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final category = resolveFileCategory(_extension);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              category.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final category = resolveFileCategory(_extension);
    if (category.isImage) {
      return FutureBuilder<void>(
        future: _ensureImageLoaded(),
        builder: (context, snapshot) {
          if (_isLoadingImage) {
            return const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
              ),
            );
          }
          if (_imageError != null) {
            return SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  _imageError!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (_imageBytes != null) {
            return SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            );
          }
          return _buildDefaultPreview(category);
        },
      );
    }
    return _buildDefaultPreview(category);
  }

  Widget _buildDefaultPreview(FileCategory category) {
    return SizedBox(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(category.icon, color: Colors.white, size: 110),
          const SizedBox(height: 16),

        ],
      ),
    );
  }

  Future<void> _ensureImageLoaded() async {
    if (_imageBytes != null || _isLoadingImage || _imageError != null) {
      return;
    }
    setState(() {
      _isLoadingImage = true;
    });
    final endpoint = context.read<ConnectionProvider>().ipfsEndpoint;
    if (endpoint == null || endpoint.isEmpty) {
      setState(() {
        _isLoadingImage = false;
        _imageError = '缺少 IPFS 地址，无法加载图片';
      });
      return;
    }
    try {
      final result = await BlockImageLoader.instance.loadVariant(
        data: _data,
        endpoint: endpoint,
        variant: ImageVariant.original,
      );
      setState(() {
        _isLoadingImage = false;
        _imageBytes = result.bytes;
      });
    } catch (error) {
      setState(() {
        _isLoadingImage = false;
        _imageError = '加载失败：$error';
      });
    }
  }

  Widget _buildFileInfo(DateTime createdAt) {
    final fileSize = _data.ipfsSize;
    final isEncrypted = _data.encryption?.isSupported ?? false;

    if (fileSize == null && !isEncrypted) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatDate(createdAt),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            children: [
              if (isEncrypted)
                const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
              if (isEncrypted && fileSize != null) const SizedBox(width: 12),
              if (fileSize != null)
                Text(
                  formatFileSize(fileSize),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildIntro(String intro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: Text(
        intro,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.6,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildBid(String bid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 36, top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BID',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            formatBid(bid),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace',
              letterSpacing: 0.8,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String get _extension => _data.extension;

  String get _displayName => _data.nameWithoutExtension;
  
  Widget _buildAudioPlayer() {
    if (_audioPlayer == null || _musicItem == null) {
      return const SizedBox.shrink();
    }
    
    final isPlaying = _audioPlayer!.isPlaying;
    final currentMusic = _audioPlayer!.currentMusic;
    final isCurrentlyPlaying = currentMusic?.bid == _musicItem!.bid;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 16),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: _togglePlayback,
            icon: Icon(
              isCurrentlyPlaying && isPlaying 
                  ? Icons.pause 
                  : Icons.play_arrow,
              color: Colors.black,
              size: 28,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
  
  Future<void> _togglePlayback() async {
    if (_audioPlayer == null || _musicItem == null) return;
    
    final currentMusic = _audioPlayer!.currentMusic;
    final isCurrentlyPlaying = currentMusic?.bid == _musicItem!.bid;
    
    if (isCurrentlyPlaying) {
      // 如果正在播放当前音频，切换播放/暂停
      if (_audioPlayer!.isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.resume();
      }
    } else {
      // 播放新音频
      final endpoint = context.read<ConnectionProvider>().ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('未配置 IPFS 节点，无法播放音频'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      try {
        await _audioPlayer!.play(_musicItem!, endpoint: endpoint);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

