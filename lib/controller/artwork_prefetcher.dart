import 'dart:io';

import 'package:flutter/painting.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

/// The player paints its artwork uncompressed, so switching to an item that has nothing
/// decoded re-reads and re-decodes the file while it is already on screen.
///
/// by claude
class ArtworkPrefetcher {
  static final inst = ArtworkPrefetcher._();
  ArtworkPrefetcher._();

  int _generation = 0;

  void prefetchAround(int index) {
    final queue = Player.inst.currentQueue.value;
    if (queue.length < 2) return;

    final generation = ++_generation;
    bool isLatest() => generation == _generation;

    final prev = Player.inst.previousIndexFor(index);
    final next = Player.inst.nextIndexFor(index);
    _prefetchAt(queue, prev, isLatest);
    if (next != prev) _prefetchAt(queue, next, isLatest);
  }

  void _prefetchAt(List<Playable> queue, int index, bool Function() isLatest) {
    if (index < 0 || index >= queue.length) return;
    queue[index].execute(
      selectable: (finalItem) => _precacheFile(File(finalItem.track.pathToImage)),
      youtubeID: (finalItem) => _prefetchYoutube(finalItem, isLatest),
    );
  }

  void _prefetchYoutube(YoutubeID item, bool Function() isLatest) async {
    final cached = ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: item.id, type: ThumbnailType.video);
    if (cached != null) return _precacheFile(cached);

    final fetched = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: item.id, isImportantInCache: true, type: ThumbnailType.video);
    if (fetched != null && isLatest()) _precacheFile(fetched);
  }

  /// [precacheImage] needs a context, the player paints artwork through [ArtworkWidget.fullQualityImage]
  /// which ignores the configuration, so the empty one lands on the very same cache key.
  void _precacheFile(File file) {
    final stream = ArtworkWidget.fullQualityImage(FileImage(file)).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {
        image.dispose();
        stream.removeListener(listener);
      },
      onError: (_, _) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  }
}
