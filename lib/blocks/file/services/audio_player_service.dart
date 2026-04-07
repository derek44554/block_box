import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/storage/cache/audio_cache.dart';
import '../../../utils/ipfs_file_helper.dart';
import '../models/audio_item.dart';

/// 音频播放服务，用于 block 级别的音频文件播放
class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  AudioItem? _currentMusic;
  bool _isPlaying = false;

  AudioPlayerService() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      notifyListeners();
    });
  }

  AudioItem? get currentMusic => _currentMusic;
  bool get isPlaying => _isPlaying;

  Future<void> play(AudioItem music, {required String endpoint}) async {
    final cid = music.audioCid;
    if (cid.isEmpty) throw Exception('音频 CID 为空');

    final ipfs = music.block.map('ipfs');
    final extension = (ipfs['ext'] as String?) ?? '.mp3';

    _currentMusic = music;
    await _player.stop();

    final cachedFile = await AudioCacheHelper.getCachedAudio(cid, extension);
    if (cachedFile != null) {
      await _player.play(DeviceFileSource(cachedFile.path));
      notifyListeners();
      return;
    }

    final url = IpfsFileHelper.buildUrl(endpoint: endpoint, cid: cid);
    if (url == null) throw Exception('无法构建 IPFS URL');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('下载失败: HTTP ${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    final savedFile = await AudioCacheHelper.saveAudioToCache(cid, bytes, extension);
    await _player.play(DeviceFileSource(savedFile.path));
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.resume();
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
