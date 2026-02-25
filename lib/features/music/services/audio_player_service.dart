import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/storage/cache/audio_cache.dart';
import '../../../utils/ipfs_file_helper.dart';
import '../models/music_models.dart';


/// 音频播放服务，封装 audioplayers 库
class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  
  MusicItem? _currentMusic;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  /// 播放完成回调
  void Function()? onPlaybackComplete;
  
  AudioPlayerService() {
    _initPlayer();
  }

  void _initPlayer() {
    // 监听播放状态变化
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    // 监听播放进度
    _player.onPositionChanged.listen((position) {
      _position = position;
      notifyListeners();
    });

    // 监听音频时长
    _player.onDurationChanged.listen((duration) {
      _duration = duration;
      notifyListeners();
    });

    // 监听播放完成
    _player.onPlayerComplete.listen((_) {
      _position = Duration.zero;
      notifyListeners();
      
      // 触发播放完成回调
      if (onPlaybackComplete != null) {
        onPlaybackComplete!();
      }
    });
  }

  MusicItem? get currentMusic => _currentMusic;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0.0;

  /// 播放音乐（带缓存支持）
  Future<void> play(MusicItem music, {required String endpoint}) async {
    try {
      final cid = music.audioCid;
      if (cid.isEmpty) {
        throw Exception('音乐 CID 为空');
      }

      // 获取音频扩展名
      final ipfs = music.block.map('ipfs');
      final extension = (ipfs['ext'] as String?) ?? '.mp3';

      _currentMusic = music;
      await _player.stop();

      // 1. 检查本地缓存
      final cachedFile = await AudioCacheHelper.getCachedAudio(cid, extension);
      if (cachedFile != null) {
        await _player.play(DeviceFileSource(cachedFile.path));
        notifyListeners();
        return;
      }

      // 2. 从网络加载
      final url = IpfsFileHelper.buildUrl(endpoint: endpoint, cid: cid);
      if (url == null) {
        throw Exception('无法构建 IPFS URL');
      }

      // 下载并缓存
      final bytes = await _downloadAudio(url);
      
      // 保存到缓存
      final savedFile = await AudioCacheHelper.saveAudioToCache(cid, bytes, extension);
      
      // 播放缓存文件
      await _player.play(DeviceFileSource(savedFile.path));
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// 下载音频文件
  Future<Uint8List> _downloadAudio(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('下载失败: HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  /// 暂停
  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  /// 恢复播放
  Future<void> resume() async {
    await _player.resume();
    notifyListeners();
  }

  /// 停止
  Future<void> stop() async {
    await _player.stop();
    _currentMusic = null;
    _position = Duration.zero;
    notifyListeners();
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

