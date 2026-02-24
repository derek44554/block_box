import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/connection_provider.dart';
import '../models/music_models.dart';
import '../providers/music_provider.dart';

/// 底部音乐播放器组件，显示当前播放的音乐和控制按钮
class MusicPlayer extends StatelessWidget {
  const MusicPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, _) {
        final currentPlaying = musicProvider.currentPlaying;
        
        if (currentPlaying == null) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              _buildProgressBar(context, musicProvider),
              // 控制面板
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    // 封面
                    _buildCover(currentPlaying),
                    const SizedBox(width: 16),
                    // 音乐信息
                    Expanded(
                      child: _buildMusicInfo(currentPlaying, musicProvider),
                    ),
                    const SizedBox(width: 16),
                    // 控制按钮
                    _buildControls(context, musicProvider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, MusicProvider musicProvider) {
    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        
        final localPosition = details.localPosition.dx;
        final width = box.size.width;
        final progress = (localPosition / width).clamp(0.0, 1.0);
        final position = musicProvider.duration * progress;
        
        musicProvider.seek(position);
      },
      child: SizedBox(
        height: 3,
        child: Stack(
          children: [
            // 背景
            Container(
              color: Colors.white.withOpacity(0.1),
            ),
            // 进度
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: musicProvider.progress.clamp(0.0, 1.0),
              child: Container(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(MusicItem music) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: music.coverCid != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                'https://ipfs.io/ipfs/${music.coverCid}',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
              ),
            )
          : _buildDefaultCover(),
    );
  }

  Widget _buildDefaultCover() {
    return const Icon(
      Icons.music_note,
      color: Colors.white38,
      size: 28,
    );
  }

  Widget _buildMusicInfo(MusicItem music, MusicProvider musicProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          music.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              _formatTime(musicProvider.position),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const Text(
              ' / ',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
            Text(
              _formatTime(musicProvider.duration),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildControls(BuildContext context, MusicProvider musicProvider) {
    final connectionProvider = context.read<ConnectionProvider>();
    final endpoint = connectionProvider.ipfsEndpoint;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上一首
        IconButton(
          onPressed: endpoint != null && endpoint.isNotEmpty
              ? () => musicProvider.playPrevious(endpoint: endpoint)
              : null,
          icon: Icon(
            Icons.skip_previous,
            color: endpoint != null && endpoint.isNotEmpty
                ? Colors.white70
                : Colors.white24,
          ),
          iconSize: 32,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        // 播放/暂停
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => musicProvider.togglePlayback(),
            icon: Icon(
              musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
            ),
            iconSize: 24,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 16),
        // 下一首
        IconButton(
          onPressed: endpoint != null && endpoint.isNotEmpty
              ? () => musicProvider.playNext(endpoint: endpoint)
              : null,
          icon: Icon(
            Icons.skip_next,
            color: endpoint != null && endpoint.isNotEmpty
                ? Colors.white70
                : Colors.white24,
          ),
          iconSize: 32,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

