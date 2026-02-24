import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/utils/formatters/file_size_formatter.dart';
import '../../../core/utils/helpers/platform_helper.dart';
import '../../common/block_detail_page.dart';
import '../../../state/connection_provider.dart';
import '../../../utils/ipfs_file_helper.dart';
import '../models/file_card_data.dart';
import '../../../state/block_detail_listener_mixin.dart';


class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> with BlockDetailListenerMixin {
  late FileCardData _data;
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _isLoading = false;
  String? _error;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _data = FileCardData.fromBlock(updatedBlock);
      // Reset video player if file changed
      _controller?.removeListener(_videoListener);
      _controller?.dispose();
      _controller = null;
      _isInitializing = false;
      _isLoading = false;
      _error = null;
    });
    // Reinitialize video with new data
    _initializeVideo();
  }

  @override
  void initState() {
    super.initState();
    _data = FileCardData.fromBlock(widget.block);
    startBlockProviderListener();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeVideo());
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    stopBlockProviderListener();
    super.dispose();
  }

  void _safeSetState(VoidCallback action) {
    if (!mounted) return;
    setState(action);
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing || _controller != null) {
      return;
    }
    _isInitializing = true;

    _safeSetState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final endpoint = context.read<ConnectionProvider>().ipfsEndpoint;
      if (endpoint == null || endpoint.isEmpty) {
        throw Exception('IPFS endpoint is not set');
      }

      final cid = _data.cid;
      if (cid == null || cid.isEmpty) {
        throw Exception('CID is missing');
      }

      final isEncrypted = _data.encryption?.isSupported ?? false;
      final extension = _data.extension.toLowerCase();
      VideoPlayerController controller;

      // 加密视频需要先下载并解密
      if (isEncrypted) {
        final bytes = await IpfsFileHelper.loadRawByCid(
          endpoint: endpoint,
          data: _data,
        );
        // 保存到临时文件
        final tempDir = Directory.systemTemp;
        final fileExtension = extension.isNotEmpty ? extension : 'mp4';
        final tempFile = File('${tempDir.path}/video_${cid}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
        await tempFile.writeAsBytes(bytes);
        controller = VideoPlayerController.file(tempFile);
      } else {
        // 未加密视频先尝试使用网络 URL 流式播放
        final url = IpfsFileHelper.buildUrl(endpoint: endpoint, cid: cid);
        if (url == null) {
          throw Exception('Could not build IPFS URL');
        }
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      // 尝试初始化，如果失败（可能是 FLV 格式不支持流式播放），则下载到本地
      try {
        await controller.initialize();
      } catch (error) {
        // 如果网络 URL 初始化失败，且不是加密视频，尝试下载到本地文件
        if (!isEncrypted) {
          controller.dispose();
          // 下载整个文件到本地
          final bytes = await IpfsFileHelper.loadRawByCid(
            endpoint: endpoint,
            data: _data,
          );
          final tempDir = Directory.systemTemp;
          final fileExtension = extension.isNotEmpty ? extension : 'mp4';
          final tempFile = File('${tempDir.path}/video_${cid}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension');
          await tempFile.writeAsBytes(bytes);
          controller = VideoPlayerController.file(tempFile);
          await controller.initialize();
        } else {
          rethrow;
        }
      }

      controller.addListener(_videoListener);

      _safeSetState(() {
        _controller = controller;
        _isLoading = false;
        _duration = controller.value.duration;
        _isPlaying = controller.value.isPlaying;
      });
    } catch (error) {
      _safeSetState(() {
        _isLoading = false;
        _error = '加载失败：$error';
      });
    } finally {
      _isInitializing = false;
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;
    _safeSetState(() {
      _isPlaying = _controller!.value.isPlaying;
      _position = _controller!.value.position;
      _duration = _controller!.value.duration;
    });
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _seekTo(Duration position) {
    if (_controller == null) return;
    _controller!.seekTo(position);
  }

  void _openFullScreen() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPage(controller: _controller!),
        fullscreenDialog: true,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _data.fileName;
    final intro = _data.intro;
    final bid = _data.bid;
    final createdAt = _data.createdAt;
    final isMacOS = PlatformHelper.isMacOS;
    final horizontalPadding = isMacOS ? 48.0 : 24.0;
    final topPadding = isMacOS ? 32.0 : 20.0;
    final bottomPadding = isMacOS ? 80.0 : 60.0;

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
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    SizedBox(height: isMacOS ? 64.0 : 48.0),
                    _buildVideoSection(),
                    _buildFileInfo(createdAt),
                    if (_data.gps != null) _buildGpsInfo(_data.gps!),
                    if (fileName.isNotEmpty) _buildTitle(fileName),
                    if (intro != null && intro.isNotEmpty) _buildIntro(intro),
                    if (bid.isNotEmpty) _buildBid(bid),
                    SizedBox(height: isMacOS ? 120.0 : 100.0),
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
    final isMacOS = PlatformHelper.isMacOS;
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMacOS ? 20.0 : 16.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMacOS ? 16.0 : 12.0,
              vertical: isMacOS ? 8.0 : 6.0,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: isMacOS ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(isMacOS ? 10.0 : 16.0),
            ),
            child: Text(
              '视频文件',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMacOS ? 13.0 : 12.0,
                fontWeight: FontWeight.w600,
                letterSpacing: isMacOS ? 1.2 : 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    final isMacOS = PlatformHelper.isMacOS;
    return Padding(
      padding: EdgeInsets.only(bottom: isMacOS ? 40.0 : 32.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMacOS ? 12.0 : 16.0),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildVideoContent(),
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_isLoading) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white24,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_controller != null && _controller!.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          _buildVideoControls(),
        ],
      );
    }

    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.videocam_outlined, color: Colors.white24, size: 64),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Stack(
      children: [
        // 播放/暂停按钮区域
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        // 进度条和控制栏
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {}, // 阻止事件冒泡
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProgressBar(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatDuration(_duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              _openFullScreen();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.fullscreen,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    if (_duration == Duration.zero) {
      return const SizedBox.shrink();
    }
    final progress = _position.inMilliseconds / _duration.inMilliseconds;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            if (_controller == null) return;
            final x = details.localPosition.dx;
            final ratio = (x / constraints.maxWidth).clamp(0.0, 1.0);
            _seekTo(Duration(milliseconds: (_duration.inMilliseconds * ratio).round()));
          },
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileInfo(DateTime createdAt) {
    final fileSize = _data.ipfsSize;
    final isEncrypted = _data.encryption?.isSupported ?? false;
    final isMacOS = PlatformHelper.isMacOS;

    if (fileSize == null &&
        !isEncrypted &&
        createdAt == DateTime.fromMillisecondsSinceEpoch(0)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isMacOS ? 32.0 : 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatDate(createdAt),
            style: TextStyle(
              color: Colors.white54,
              fontSize: isMacOS ? 14.0 : 13.0,
              letterSpacing: isMacOS ? 1.0 : 1.2,
            ),
          ),
          Row(
            children: [
              if (isEncrypted)
                Icon(
                  Icons.lock_outline,
                  color: Colors.white70,
                  size: isMacOS ? 22.0 : 20.0,
                ),
              if (isEncrypted && fileSize != null)
                SizedBox(width: isMacOS ? 16.0 : 12.0),
              if (fileSize != null)
                Text(
                  formatFileSize(fileSize),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isMacOS ? 15.0 : 14.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(GpsCoordinates gps) async {
    final lat = gps.latitude;
    final lon = gps.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开地图应用')));
      }
    }
  }

  Widget _buildGpsInfo(GpsCoordinates gps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: () => _openMap(gps),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Colors.white54,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${gps.latitude.toStringAsFixed(6)}, ${gps.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new, color: Colors.white38, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    final isMacOS = PlatformHelper.isMacOS;
    return Padding(
      padding: EdgeInsets.only(bottom: isMacOS ? 20.0 : 16.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: isMacOS ? 44.0 : 40.0,
          fontWeight: FontWeight.w700,
          letterSpacing: isMacOS ? -1.0 : -1.2,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildIntro(String intro) {
    final isMacOS = PlatformHelper.isMacOS;
    return Container(
      margin: EdgeInsets.only(bottom: isMacOS ? 48.0 : 40.0),
      child: Text(
        intro,
        style: TextStyle(
          color: Colors.white,
          fontSize: isMacOS ? 17.0 : 16.0,
          height: 1.6,
          letterSpacing: isMacOS ? 0.2 : 0.3,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildBid(String bid) {
    final isMacOS = PlatformHelper.isMacOS;
    return Container(
      margin: EdgeInsets.only(
        bottom: isMacOS ? 40.0 : 36.0,
        top: isMacOS ? 40.0 : 36.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BID',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: isMacOS ? 12.0 : 11.0,
              fontWeight: FontWeight.w600,
              letterSpacing: isMacOS ? 1.0 : 1.2,
            ),
          ),
          SizedBox(height: isMacOS ? 10.0 : 8.0),
          SelectableText(
            formatBid(bid),
            style: TextStyle(
              color: Colors.white,
              fontSize: isMacOS ? 15.0 : 14.0,
              fontFamily: 'monospace',
              letterSpacing: isMacOS ? 0.6 : 0.8,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;

  const FullScreenVideoPage({super.key, required this.controller});

  @override
  State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    _duration = widget.controller.value.duration;
    _position = widget.controller.value.position;
    widget.controller.addListener(_videoListener);
    _resetHideControlsTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // 允许所有方向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    widget.controller.removeListener(_videoListener);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 恢复所有方向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _videoListener() {
    if (!mounted) return;
    setState(() {
      _isPlaying = widget.controller.value.isPlaying;
      _position = widget.controller.value.position;
      _duration = widget.controller.value.duration;
    });
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _resetHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _resetHideControlsTimer();
  }

  void _seekTo(Duration position) {
    widget.controller.seekTo(position);
    _resetHideControlsTimer();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    _resetHideControlsTimer();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 根据当前方向更新状态
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.landscape && !_isLandscape) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLandscape = true;
          });
        }
      });
    } else if (orientation == Orientation.portrait && _isLandscape) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLandscape = false;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            if (_showControls) _buildFullScreenControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部栏：返回按钮和旋转按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleOrientation,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isLandscape ? Icons.screen_lock_portrait : Icons.screen_lock_rotation,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 播放/暂停按钮
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            const Spacer(),
            // 底部控制栏
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFullScreenProgressBar(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenProgressBar() {
    if (_duration == Duration.zero) {
      return const SizedBox.shrink();
    }
    final progress = _position.inMilliseconds / _duration.inMilliseconds;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            final x = details.localPosition.dx;
            final ratio = (x / constraints.maxWidth).clamp(0.0, 1.0);
            _seekTo(Duration(milliseconds: (_duration.inMilliseconds * ratio).round()));
          },
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
