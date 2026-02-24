import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../blocks/file/models/file_card_data.dart';
import '../core/storage/cache/image_cache.dart';
import 'cid_image_provider.dart';
import 'ipfs_file_helper.dart';

/// 图片加载来源，用于调试与分析缓存命中情况。
enum ImageLoadSource { memory, disk, network, external }

/// 图片加载结果，统一封装返回的字节数据与 [ImageProvider]。
class BlockImageResult {
  BlockImageResult({
    required this.bytes,
    required this.variant,
    required this.provider,
    required this.source,
    this.loadDurationMs,
  });

  final Uint8List bytes;
  final ImageVariant variant;
  final ImageProvider provider;
  final ImageLoadSource source;
  final int? loadDurationMs;
}

/// `BlockImageLoader` 负责统一管理 CID 图片的加载。
///
/// - 优先命中内存缓存，其次命中磁盘缓存；
/// - 自动去重网络请求，防止同一个 CID 在多个组件中重复下载；
/// - 保持 `ImageCacheHelper` 的缓存同步，并返回可直接用于 Widget 的 `ImageProvider`。
class BlockImageLoader {
  BlockImageLoader._();

  static final BlockImageLoader instance = BlockImageLoader._();

  final _pendingLoads = HashMap<String, Future<Uint8List>>();

  /// 根据给定 `FileCardData` 拉取指定 [variant] 的图片数据。
  ///
  /// [endpoint] 为当前连接的 IPFS 节点地址。
  /// [initialBytes] 可用于传入外部已有的字节数据，例如缩略图。
  /// [initialVariant] 标记 `initialBytes` 对应的尺寸，便于直接写入缓存。
  Future<BlockImageResult> loadVariant({
    required FileCardData data,
    required String endpoint,
    ImageVariant variant = ImageVariant.medium,
    Uint8List? initialBytes,
    ImageVariant? initialVariant,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    final cid = data.cid?.trim() ?? '';
    if (cid.isEmpty) {
      throw StateError('缺少 CID，无法加载图片（bid=${data.bid}）');
    }

    Uint8List? bytes;

    if (initialBytes != null && initialBytes.isNotEmpty) {
      final variantOfInitial = initialVariant ?? variant;
      _updateMemoryCache(cid, variantOfInitial, initialBytes);
      // 只有当外部传入的是我们需要的目标变体时，才保存到磁盘
      if (variantOfInitial == variant) {
        unawaited(ImageCacheHelper.saveImageToCache(cid, initialBytes, variant: variant));
        stopwatch.stop();
        return _buildResult(
          cid: cid,
          bytes: initialBytes,
          variant: variant,
          source: ImageLoadSource.external,
          loadDurationMs: stopwatch.elapsedMilliseconds,
        );
      }
    }

    bytes = ImageCacheHelper.getMemoryImage(cid, variant: variant);
    if (bytes != null) {
      stopwatch.stop();
      return _buildResult(
        cid: cid,
        bytes: bytes,
        variant: variant,
        source: ImageLoadSource.memory,
        loadDurationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final cachedFile = await ImageCacheHelper.getCachedImage(
      cid,
      variant: variant,
    );
    if (cachedFile != null) {
      try {
        bytes = await cachedFile.readAsBytes();
        // 仅更新内存缓存，不需要重新写回磁盘
        _updateMemoryCache(cid, variant, bytes);
        stopwatch.stop();
        return _buildResult(
          cid: cid,
          bytes: bytes,
          variant: variant,
          source: ImageLoadSource.disk,
          loadDurationMs: stopwatch.elapsedMilliseconds,
        );
      } catch (error, stackTrace) {
        // 磁盘缓存读取失败，继续从网络加载
      }
    }

    final normalizedEndpoint = endpoint.trim();
    if (normalizedEndpoint.isEmpty) {
      throw StateError('未配置 IPFS 节点，无法下载图片');
    }

    final loadKey = _composePendingKey(cid, variant);
    final existingFuture = _pendingLoads[loadKey];
    if (existingFuture != null) {
      final sharedBytes = await existingFuture;
      stopwatch.stop();
      return _buildResult(
        cid: cid,
        bytes: sharedBytes,
        variant: variant,
        source: ImageLoadSource.network,
        loadDurationMs: stopwatch.elapsedMilliseconds,
      );
    }

    final future = IpfsFileHelper.downloadFromNetwork(
      endpoint: normalizedEndpoint,
      data: data,
    );
    _pendingLoads[loadKey] = future;

    try {
      final downloaded = await future;
      
      // 更新内存缓存
      _updateMemoryCache(cid, variant, downloaded);
      
      // 显式保存到磁盘缓存
      unawaited(ImageCacheHelper.saveImageToCache(cid, downloaded, variant: variant));
      
      stopwatch.stop();
      return _buildResult(
        cid: cid,
        bytes: downloaded,
        variant: variant,
        source: ImageLoadSource.network,
        loadDurationMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      _pendingLoads.remove(loadKey);
    }
  }

  void _updateMemoryCache(String cid, ImageVariant variant, Uint8List bytes) {
    ImageCacheHelper.cacheMemoryImage(cid, bytes, variant: variant);
    // warmUpMemoryCache 现在只做内存缓存更新，不再解码，保留调用以防未来修改
    unawaited(ImageCacheHelper.warmUpMemoryCache(cid, bytes, variant: variant));
  }

  BlockImageResult _buildResult({
    required String cid,
    required Uint8List bytes,
    required ImageVariant variant,
    required ImageLoadSource source,
    int? loadDurationMs,
  }) {
    final provider = CidImageProvider(
      cid: ImageCacheHelper.composeKey(cid, variant),
      bytesResolver: () async => bytes,
      scale: 1.0,
    );

    return BlockImageResult(
      bytes: bytes,
      variant: variant,
      provider: provider,
      source: source,
      loadDurationMs: loadDurationMs,
    );
  }

  String _composePendingKey(String cid, ImageVariant variant) {
    return '${variant.name}::${ImageCacheHelper.composeKey(cid, variant)}';
  }
}
