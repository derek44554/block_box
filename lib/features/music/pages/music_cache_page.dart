import 'package:flutter/material.dart';

import '../../../core/storage/cache/audio_cache.dart';
import 'package:block_app/core/widgets/dialogs/confirmation_dialog.dart';

/// 音乐缓存管理页面
class MusicCachePage extends StatefulWidget {
  const MusicCachePage({super.key});

  @override
  State<MusicCachePage> createState() => _MusicCachePageState();
}

class _MusicCachePageState extends State<MusicCachePage> {
  int _cacheCount = 0;
  int _cacheSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final count = await AudioCacheHelper.getCacheCount();
      final size = await AudioCacheHelper.getCacheSize();

      if (!mounted) return;

      setState(() {
        _cacheCount = count;
        _cacheSize = size;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[MusicCachePage] 加载缓存信息失败: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showConfirmationDialog(
      context: context,
      title: '清空音乐缓存？',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前缓存：$_cacheCount 个文件，${AudioCacheHelper.formatCacheSize(_cacheSize)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text(
            '清空后需要重新下载音乐文件',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      confirmText: '清空',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      await AudioCacheHelper.clearAllCache();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('缓存已清空'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadCacheInfo();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清空失败: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('音乐缓存'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white24,
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildActionButtons(),
          const SizedBox(height: 32),
          _buildDescription(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.music_note,
            label: '缓存文件',
            value: '$_cacheCount 个',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.storage,
            label: '占用空间',
            value: AudioCacheHelper.formatCacheSize(_cacheSize),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white54,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loadCacheInfo,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _cacheCount > 0 ? _clearCache : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: _cacheCount > 0
                    ? Colors.red.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
              ),
              foregroundColor: _cacheCount > 0 ? Colors.red[300] : Colors.white38,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('清空缓存'),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '缓存说明',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 首次播放音乐时会自动下载并缓存\n'
            '• 再次播放相同音乐时直接使用缓存\n'
            '• 缓存文件保存在应用数据目录\n'
            '• 根据 CID 识别，不会重复下载',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

