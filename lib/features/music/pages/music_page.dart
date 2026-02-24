import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/layouts/segmented_page_scaffold.dart';
import '../providers/music_provider.dart';
import 'music_cache_page.dart';
import 'music_collection_page.dart';
import 'music_play_page.dart';
import 'music_player.dart';

/// 音乐页面展示播放列表和集合管理，支持本地集合管理和音乐播放。

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  int _currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 使用 SegmentedPageScaffold 提供的分段控制
            Expanded(
              child: _buildPageContent(),
            ),
            // 底部播放器（仅在播放页面显示）
            if (_currentPageIndex == 0)
              Consumer<MusicProvider>(
                builder: (context, musicProvider, _) {
                  if (musicProvider.currentPlaying != null) {
                    return const MusicPlayer();
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    return SegmentedPageScaffold(
      title: '音乐',
      segments: const ['播放', '集合'],
      pages: const [
        MusicPlayPage(),
        MusicCollectionPage(),
      ],
      initialIndex: _currentPageIndex,
      onIndexChanged: (index) {
        setState(() {
          _currentPageIndex = index;
        });
      },
      controlWidth: 140,
      headerPadding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
      bottomSafeArea: false,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.folder_outlined,
            color: Colors.white70,
            size: 20,
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MusicCachePage(),
              ),
            );
          },
          tooltip: '缓存管理',
        ),
      ],
    );
  }
}

