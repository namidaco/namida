import 'dart:ui' as ui;

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

// by claude
/// decides what pip shows and pushes its aspect ratio ahead of time, android can't wait for dart while the app is leaving.
class PipController {
  static final inst = PipController._();
  PipController._();

  static const _kSquareRatio = (width: 1, height: 1);
  static const _kLyricsRatio = (width: 4, height: 3);
  static const _kAndroidMaxRatio = (width: 239, height: 100);

  final content = Rxn<PipContent>();

  _PipRatio? _artworkRatio;
  _PipRatio? _pushedRatio;
  bool _isListeningToLyrics = false;
  bool _isListeningToItem = false;
  bool _isListeningToItemLoading = false;

  void init() {
    settings.pipContents.addListener(_onContentsChanged);
    _onContentsChanged();
  }

  bool isLyricsEnabled() => settings.pipContents.value.contains(PipContent.lyrics);

  void onVideoInfoChanged() => _refresh();

  void _onContentsChanged() {
    final contents = settings.pipContents.value;

    final shouldListenToLyrics = contents.contains(PipContent.lyrics);
    if (shouldListenToLyrics != _isListeningToLyrics) {
      _isListeningToLyrics = shouldListenToLyrics;
      if (shouldListenToLyrics) {
        Lyrics.inst.currentLyricsLRC.addListener(_refresh);
        Lyrics.inst.isResolvingLyrics.addListener(_refresh);
      } else {
        Lyrics.inst.currentLyricsLRC.removeListener(_refresh);
        Lyrics.inst.isResolvingLyrics.removeListener(_refresh);
      }
    }

    final shouldListenToItemLoading = shouldListenToLyrics || contents.contains(PipContent.video);
    if (shouldListenToItemLoading != _isListeningToItemLoading) {
      _isListeningToItemLoading = shouldListenToItemLoading;
      if (shouldListenToItemLoading) {
        Player.inst.isLoadingCurrentItem.addListener(_refresh);
      } else {
        Player.inst.isLoadingCurrentItem.removeListener(_refresh);
      }
    }

    final shouldListenToItem = contents.contains(PipContent.artwork);
    if (shouldListenToItem != _isListeningToItem) {
      _isListeningToItem = shouldListenToItem;
      if (shouldListenToItem) {
        Player.inst.currentItem.addListener(_onItemChanged);
        _resolveArtworkRatio();
      } else {
        Player.inst.currentItem.removeListener(_onItemChanged);
        _artworkRatio = null;
      }
    }

    _refresh();
  }

  void _onItemChanged() {
    _artworkRatio = null;
    _refresh();
    _resolveArtworkRatio();
  }

  Future<void> _resolveArtworkRatio() async {
    final item = Player.inst.currentItem.value;
    if (item == null) return;
    final ratio = await _readArtworkRatio(item);
    if (item != Player.inst.currentItem.value) return;
    _artworkRatio = ratio ?? _kSquareRatio;
    _refresh();
  }

  void _refresh() {
    final contents = settings.pipContents.value;
    final resolved = _resolve(contents);
    if (resolved == null) return;
    final (newContent, ratio) = resolved;
    content.value = newContent;
    if (ratio == _pushedRatio) return;
    _pushedRatio = ratio;
    NamidaChannel.inst.setPipAspectRatio(width: ratio?.width, height: ratio?.height);
  }

  /// null while a higher priority content is still loading, the previous content and ratio stay until it settles.
  (PipContent?, _PipRatio?)? _resolve(Set<PipContent> contents) {
    final isLoadingItem = Player.inst.isLoadingCurrentItem.value;
    if (contents.contains(PipContent.video)) {
      final videoRatio = _getVideoRatio();
      if (videoRatio != null) return (PipContent.video, videoRatio);
      if (isLoadingItem) return null;
    }
    if (contents.contains(PipContent.lyrics)) {
      if (Lyrics.inst.currentLyricsLRC.value != null) return (PipContent.lyrics, _kLyricsRatio);
      if (isLoadingItem || Lyrics.inst.isResolvingLyrics.value) return null;
    }
    if (contents.contains(PipContent.artwork) && Player.inst.currentItem.value != null) {
      final artworkRatio = _artworkRatio;
      if (artworkRatio == null) return null;
      return (PipContent.artwork, artworkRatio);
    }
    return (null, null);
  }

  static _PipRatio? _getVideoRatio() {
    final info = Player.inst.videoPlayerInfo.value;
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return _clampRatio(info.width, info.height);
  }

  static _PipRatio _clampRatio(int width, int height) {
    if (width * _kAndroidMaxRatio.height > height * _kAndroidMaxRatio.width) return _kAndroidMaxRatio;
    if (height * _kAndroidMaxRatio.height > width * _kAndroidMaxRatio.width) return (width: _kAndroidMaxRatio.height, height: _kAndroidMaxRatio.width);
    return (width: width, height: height);
  }

  static Future<_PipRatio?> _readArtworkRatio(Playable item) async {
    final buffer = await getArtworkBuffer(item);
    if (buffer == null) return null;
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final ratio = _clampRatio(descriptor.width, descriptor.height);
      descriptor.dispose();
      return ratio;
    } catch (_) {
      return null;
    } finally {
      buffer.dispose();
    }
  }

  static Future<ui.ImmutableBuffer?> getArtworkBuffer(Playable item) async {
    try {
      if (item is YoutubeID) {
        final file = await ThumbnailManager.inst.getYoutubeThumbnailFromCache(id: item.id, isTemp: null, type: ThumbnailType.video);
        if (file == null) return null;
        return await ui.ImmutableBuffer.fromFilePath(file.path);
      }
      if (item is Selectable) {
        final track = item.track;
        final artwork = await Indexer.inst.getArtwork(imagePath: track.pathToImage, track: track, compressed: false);
        final file = artwork.file;
        if (file != null) return await ui.ImmutableBuffer.fromFilePath(file.path);
        final bytes = artwork.bytes;
        if (bytes != null) return await ui.ImmutableBuffer.fromUint8List(bytes);
      }
    } catch (_) {}
    return null;
  }
}

typedef _PipRatio = ({int width, int height});
