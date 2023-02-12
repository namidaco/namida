import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CacheImageProvider extends ImageProvider<CacheImageProvider> {
  final String tag; //the cache id use to get cache
  final Uint8List img; //the bytes of image to cache

  CacheImageProvider(this.tag, this.img);

  @override
  ImageStreamCompleter load(CacheImageProvider key, Future<Codec> Function(Uint8List, {bool allowUpscaling, int? cacheHeight, int? cacheWidth}) decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(decode),
      scale: 1.0,
      debugLabel: tag,
      informationCollector: () sync* {
        yield ErrorDescription('Tag: $tag');
      },
    );
  }

  Future<Codec> _loadAsync(Future<Codec> Function(Uint8List, {bool allowUpscaling, int? cacheHeight, int? cacheWidth}) decode) async {
    // the DefaultCacheManager() encapsulation, it get cache from local storage.
    final Uint8List bytes = img;

    if (bytes.lengthInBytes == 0) {
      // The file may become available later.
      PaintingBinding.instance.imageCache.evict(this);
      throw StateError('$tag is empty and cannot be loaded as an image.');
    }

    return await decode(bytes);
  }

  @override
  Future<CacheImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CacheImageProvider>(this);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    bool res = other is CacheImageProvider && other.tag == tag;
    return res;
  }

  @override
  int get hashCode => tag.hashCode;

  @override
  String toString() => '${objectRuntimeType(this, 'CacheImageProvider')}("$tag")';
}
