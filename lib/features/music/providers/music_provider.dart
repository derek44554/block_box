import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/music_models.dart';
import '../services/audio_player_service.dart';

const _musicCollectionsKey = 'music_collections_data';

/// 音乐状态管理，负责集合管理和持久化
class MusicProvider extends ChangeNotifier {
  MusicProvider() {
    _restore();
    _audioService.addListener(_onAudioServiceChanged);
    _audioService.onPlaybackComplete = _onPlaybackComplete;
  }

  final AudioPlayerService _audioService = AudioPlayerService();
  List<MusicCollection> _collections = const [];
  List<MusicItem> _playlist = const [];
  String? _lastEndpoint; // 保存最后使用的 endpoint
  String? _selectedCollectionBid; // 当前选中的集合 BID

  void _onAudioServiceChanged() {
    notifyListeners();
  }

  /// 播放完成时自动播放下一首
  void _onPlaybackComplete() {
    if (currentPlaying == null || _playlist.isEmpty) {
      return;
    }
    
    final currentIndex = _playlist.indexWhere((item) => item.bid == currentPlaying!.bid);
    if (currentIndex >= 0 && currentIndex < _playlist.length - 1) {
      final nextMusic = _playlist[currentIndex + 1];
      
      // 使用保存的 endpoint
      if (_lastEndpoint != null && _lastEndpoint!.isNotEmpty) {
        play(nextMusic, endpoint: _lastEndpoint!);
      }
    }
  }

  List<MusicCollection> get collections => List.unmodifiable(_collections);

  /// 获取所有标记为播放列表的集合
  List<MusicCollection> get playlistCollections =>
      _collections.where((collection) => collection.isPlaylist).toList(growable: false);

  /// 获取当前选中的集合 BID
  String? get selectedCollectionBid => _selectedCollectionBid;

  /// 设置选中的集合
  void setSelectedCollection(String? bid) {
    if (_selectedCollectionBid != bid) {
      _selectedCollectionBid = bid;
      notifyListeners();
    }
  }

  MusicItem? get currentPlaying => _audioService.currentMusic;
  List<MusicItem> get playlist => List.unmodifiable(_playlist);
  bool get isPlaying => _audioService.isPlaying;
  Duration get duration => _audioService.duration;
  Duration get position => _audioService.position;
  double get progress => _audioService.progress;
  AudioPlayerService get audioService => _audioService;

  Future<void> setCollections(List<MusicCollection> collections) async {
    _collections = List.unmodifiable(collections);
    await _persist();
    notifyListeners();
  }

  Future<void> addCollection(MusicCollection collection) async {
    final existingIndex = _collections.indexWhere((item) => item.bid == collection.bid);
    List<MusicCollection> updated;
    if (existingIndex >= 0) {
      updated = [..._collections];
      updated[existingIndex] = collection;
    } else {
      updated = [..._collections, collection];
    }
    _collections = List.unmodifiable(updated);
    await _persist();
    notifyListeners();
  }

  Future<void> removeCollection(String bid) async {
    _collections = List.unmodifiable(_collections.where((item) => item.bid != bid));
    await _persist();
    notifyListeners();
  }

  Future<void> togglePlaylist(String bid, bool isPlaylist) async {
    final updated = _collections.map((entry) {
      if (entry.bid == bid) {
        return entry.copyWith(isPlaylist: isPlaylist);
      }
      return entry;
    }).toList(growable: false);
    _collections = List.unmodifiable(updated);
    await _persist();
    notifyListeners();
  }

  Future<void> updateCollectionBlock(String bid, Map<String, dynamic> block) async {
    final updated = _collections.map((entry) {
      if (entry.bid == bid) {
        return entry.copyWith(block: block);
      }
      return entry;
    }).toList(growable: false);
    _collections = List.unmodifiable(updated);
    await _persist();
    notifyListeners();
  }

  Future<void> reorderCollections(int oldIndex, int newIndex) async {
    final updated = [..._collections];
    final normalizedNewIndex = _normalizeNewIndex(oldIndex, newIndex, updated.length);
    final entry = updated.removeAt(oldIndex);
    updated.insert(normalizedNewIndex, entry);
    _collections = List.unmodifiable(updated);
    await _persist();
    notifyListeners();
  }

  /// 播放音乐
  Future<void> play(MusicItem item, {required String endpoint}) async {
    try {
      _lastEndpoint = endpoint; // 保存 endpoint 用于自动播放下一首
      await _audioService.play(item, endpoint: endpoint);
    } catch (e) {
      rethrow;
    }
  }

  /// 设置播放列表
  void setPlaylist(List<MusicItem> items) {
    _playlist = List.unmodifiable(items);
    notifyListeners();
  }

  /// 切换播放/暂停
  Future<void> togglePlayback() async {
    if (_audioService.isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.resume();
    }
  }

  /// 暂停
  Future<void> pause() async {
    await _audioService.pause();
  }

  /// 恢复播放
  Future<void> resume() async {
    await _audioService.resume();
  }

  /// 停止
  Future<void> stop() async {
    await _audioService.stop();
  }

  /// 播放下一首
  Future<void> playNext({required String endpoint}) async {
    if (currentPlaying == null || _playlist.isEmpty) return;
    
    final currentIndex = _playlist.indexWhere((item) => item.bid == currentPlaying!.bid);
    if (currentIndex >= 0 && currentIndex < _playlist.length - 1) {
      await play(_playlist[currentIndex + 1], endpoint: endpoint);
    }
  }

  /// 播放上一首
  Future<void> playPrevious({required String endpoint}) async {
    if (currentPlaying == null || _playlist.isEmpty) return;
    
    final currentIndex = _playlist.indexWhere((item) => item.bid == currentPlaying!.bid);
    if (currentIndex > 0) {
      await play(_playlist[currentIndex - 1], endpoint: endpoint);
    }
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _collections.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_musicCollectionsKey, payload);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getStringList(_musicCollectionsKey);
    if (payload == null || payload.isEmpty) {
      _collections = const [];
      notifyListeners();
      return;
    }

    // 在后台 Isolate 中进行 JSON 解码，避免阻塞主线程
    try {
      final restored = await compute(_parseCollections, payload);
      _collections = restored;
    } catch (e) {
      _collections = const [];
    }

    notifyListeners();
  }

  // 静态方法，用于 compute 调用
  static List<MusicCollection> _parseCollections(List<String> payload) {
    return payload
        .map((entry) => MusicCollection.fromJson(jsonDecode(entry) as Map<String, dynamic>))
        .toList(growable: false);
  }

  int _normalizeNewIndex(int oldIndex, int newIndex, int length) {
    var target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    if (target < 0) {
      target = 0;
    }
    if (target >= length) {
      target = length - 1;
    }
    return target;
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioServiceChanged);
    _audioService.dispose();
    super.dispose();
  }
}

