import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/connection_provider.dart';
import 'package:block_app/core/network/api/block_api.dart';
import '../../../core/models/block_model.dart';
import '../../../core/routing/app_router.dart';
import '../models/music_models.dart';
import '../providers/music_provider.dart';

/// 播放页面，显示当前播放列表中的音乐
class MusicPlayPage extends StatefulWidget {
  const MusicPlayPage({super.key});

  @override
  State<MusicPlayPage> createState() => _MusicPlayPageState();
}

class _MusicPlayPageState extends State<MusicPlayPage> {
  List<MusicItem> _musicItems = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 30;
  _MusicPlaylistKey? _lastLoadedKey;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<MusicProvider, _MusicPlaylistKey>(
      selector: (_, provider) => _MusicPlaylistKey(
        playlistBids: provider.playlistCollections.map((c) => c.bid).toList(),
        selectedCollectionBid: provider.selectedCollectionBid,
      ),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, playlistKey, _) {
        // 只有当 key 变化时才重新加载音乐
        if (_lastLoadedKey != playlistKey && !_isLoading) {
          _lastLoadedKey = playlistKey;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadMusic();
          });
        }

        return Consumer<MusicProvider>(
          builder: (context, musicProvider, _) {
            // 检查是否有集合和播放列表
            final hasCollections = musicProvider.collections.isNotEmpty;
            final hasPlaylistCollections = musicProvider.playlistCollections.isNotEmpty;

            if (_isLoading && _musicItems.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white24,
                ),
              );
            }

            if (_error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white24,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        _lastLoadedKey = null; // 重置标记以允许重新加载
                        _loadMusic();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }

            if (_musicItems.isEmpty) {
              return _buildEmptyState(hasCollections, hasPlaylistCollections);
            }

            return _buildMusicList();
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool hasCollections, bool hasPlaylistCollections) {
    final musicProvider = context.watch<MusicProvider>();
    final hasSelectedCollection = musicProvider.selectedCollectionBid != null;
    
    String message;
    String hint;
    IconData icon;

    if (!hasCollections) {
      message = '还没有添加音乐集合';
      hint = '请先在"集合"页面添加一个音乐集合';
      icon = Icons.library_music_outlined;
    } else if (hasSelectedCollection) {
      message = '该集合中暂无音乐';
      hint = '集合中可能还没有音乐文件';
      icon = Icons.music_off;
    } else if (!hasPlaylistCollections) {
      message = '还没有加入播放列表';
      hint = '请在"集合"页面点击选择一个集合，或长按集合选择"加入播放列表"';
      icon = Icons.playlist_add;
    } else {
      message = '播放列表中暂无音乐';
      hint = '集合中可能还没有音乐文件';
      icon = Icons.music_off;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white24,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              hint,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoading &&
            _hasMore &&
            scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          _loadMusic(loadMore: true);
        }
        return false;
      },
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        itemCount: _musicItems.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _musicItems.length) {
            return _buildLoadingIndicator();
          }
          return _buildMusicItem(_musicItems[index], index);
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white24,
        ),
      ),
    );
  }

  Widget _buildMusicItem(MusicItem music, int index) {
    final musicProvider = context.watch<MusicProvider>();
    final isPlaying = musicProvider.currentPlaying?.bid == music.bid && 
                      musicProvider.isPlaying;

    return InkWell(
      onTap: () => _playMusic(music),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // 序号或播放图标
            SizedBox(
              width: 32,
              child: Center(
                child: isPlaying
                    ? const Icon(
                        Icons.graphic_eq,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 封面
            _buildCover(music),
            const SizedBox(width: 12),
            // 音乐信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    music.title,
                    style: TextStyle(
                      color: isPlaying ? Colors.white : Colors.white.withOpacity(0.87),
                      fontSize: 15,
                      fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    music.artist ?? '未知艺术家',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 时长
            if (music.duration != null)
              Text(
                _formatDuration(music.duration!),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            const SizedBox(width: 12),
            // 更多按钮
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white38,
                size: 20,
              ),
              onPressed: () => _showMusicOptions(music),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(MusicItem music) {
    return Container(
      width: 48,
      height: 48,
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
      size: 24,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _playMusic(MusicItem music) async {
    final musicProvider = context.read<MusicProvider>();
    final connectionProvider = context.read<ConnectionProvider>();
    
    // 获取 IPFS endpoint
    final endpoint = connectionProvider.ipfsEndpoint;
    if (endpoint == null || endpoint.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('未配置 IPFS 节点，无法播放音乐'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    musicProvider.setPlaylist(_musicItems);
    
    try {
      await musicProvider.play(music, endpoint: endpoint);
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

  void _showMusicOptions(MusicItem music) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.white70),
              title: const Text('播放', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _playMusic(music);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white70),
              title: const Text('详情', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                AppRouter.openBlockDetailPage(context, music.block);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMusic({bool loadMore = false}) async {
    if (_isLoading) return;
    if (loadMore && !_hasMore) return;

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _error = null;
      }
    });

    try {
      final musicProvider = context.read<MusicProvider>();
      final selectedCollectionBid = musicProvider.selectedCollectionBid;
      final playlistCollections = musicProvider.playlistCollections;
      
      // 优先使用选中的集合，如果没有选中则使用播放列表集合
      List<String> bidsToQuery;
      if (selectedCollectionBid != null && selectedCollectionBid.isNotEmpty) {
        bidsToQuery = [selectedCollectionBid];
      } else if (playlistCollections.isNotEmpty) {
        bidsToQuery = playlistCollections.map((c) => c.bid).toList();
      } else {
        setState(() {
          _musicItems = [];
          _isLoading = false;
          _hasMore = false;
        });
        return;
      }
      
      final targetPage = loadMore ? _currentPage + 1 : 1;
      
      final api = BlockApi(
        connectionProvider: context.read<ConnectionProvider>(),
      );
      
      final response = await api.getLinksByTargets(
        bids: bidsToQuery,
        page: targetPage,
        limit: _pageSize,
        order: 'desc',
      );

      if (!mounted) return;

      final data = response['data'];
      final blocks = _extractBlocksFromResponse(data);
      final musicItems = blocks.map((block) => MusicItem.fromBlock(block)).toList();

      setState(() {
        if (loadMore) {
          _currentPage = targetPage;
          _musicItems = [..._musicItems, ...musicItems];
        } else {
          _currentPage = targetPage;
          _musicItems = musicItems;
        }
        _hasMore = blocks.length >= _pageSize;
        _isLoading = false;
      });

      // 自动设置播放列表（包含所有已加载的音乐）
      if (_musicItems.isNotEmpty) {
        musicProvider.setPlaylist(_musicItems);
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        if (!loadMore) {
          _error = '加载失败: $error\n请检查连接和集合配置';
        }
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  List<BlockModel> _extractBlocksFromResponse(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      return const <BlockModel>[];
    }

    final items = payload['items'];
    if (items is! List) {
      return const <BlockModel>[];
    }

    // 音频文件块的 model ID (这里使用与文件块相同的ID，实际使用时根据你的后端定义)
    const audioModelId = 'c4238dd0d3d95db7b473adb449f6d282';
    
    // 支持的音频扩展名
    const audioExtensions = [
      '.mp3', '.m4a', '.aac', '.ogg', '.wav', '.flac',
      '.MP3', '.M4A', '.AAC', '.OGG', '.WAV', '.FLAC',
    ];

    final allBlocks = items
        .whereType<Map<String, dynamic>>()
        .map((item) => BlockModel(data: item))
        .toList();

    // 过滤出音频块
    final audioBlocks = allBlocks.where((block) {
      final model = block.maybeString('model');
      final isAudioBlock = model == audioModelId;
      
      if (!isAudioBlock) {
        return false;
      }

      final ipfs = block.map('ipfs');
      final hasValidIpfs = !ipfs.isEmpty && ipfs['cid'] != null;
      
      if (!hasValidIpfs) {
        return false;
      }

      // 检查是否为音频格式
      final ext = ipfs['ext'] as String?;
      final isAudio = ext != null && audioExtensions.contains(ext);
      
      return isAudio;
    }).toList();
    
    return audioBlocks;
  }
}

class _MusicPlaylistKey {
  const _MusicPlaylistKey({
    required this.playlistBids,
    this.selectedCollectionBid,
  });

  final List<String> playlistBids;
  final String? selectedCollectionBid;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _MusicPlaylistKey) return false;
    return selectedCollectionBid == other.selectedCollectionBid &&
        playlistBids.length == other.playlistBids.length &&
        _listEquals(playlistBids, other.playlistBids);
  }

  @override
  int get hashCode => Object.hash(
    selectedCollectionBid,
    Object.hashAll(playlistBids),
  );

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
