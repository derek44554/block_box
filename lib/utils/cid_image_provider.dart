import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class CidImageProvider extends ImageProvider<_CidImageKey> {
  const CidImageProvider({
    required this.cid,
    required Future<Uint8List> Function() bytesResolver,
    this.scale = 1.0,
  }) : _bytesResolver = bytesResolver;

  final String cid;
  final double scale;
  final Future<Uint8List> Function() _bytesResolver;

  @override
  Future<_CidImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(_CidImageKey(cid: cid, scale: scale));
  }

  @override
  ImageStreamCompleter loadImage(_CidImageKey key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_loadAsync(key, decode));
  }

  Future<ImageInfo> _loadAsync(_CidImageKey key, ImageDecoderCallback decode) async {
    final bytes = await _bytesResolver();
    if (bytes.isEmpty) {
      throw StateError('CID "$cid" resolved empty image bytes');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image, scale: key.scale);
  }
}

class _CidImageKey {
  const _CidImageKey({required this.cid, required this.scale});

  final String cid;
  final double scale;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _CidImageKey && other.cid == cid && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(cid, scale);
}

