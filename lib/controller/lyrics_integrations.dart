// by claude
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:lrc/lrc.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/controller/home_widget_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/now_playing_broadcaster.dart';
import 'package:namida/controller/platform/home_widgets/home_widgets.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/tray_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

/// pushes the playing lyrics to the system surfaces the user enabled. `lyricInfo` rides the media metadata once per track,
/// SuperLyric & the flyme ticker get one call per line. an instance only exists while at least one is on.
class LyricsIntegrations {
  static LyricsIntegrations? _instance;

  static bool get isActive => _instance != null;

  /// media items go through here before being published, to get the `lyricInfo` extra when available.
  static MediaItem prepareMediaItem(MediaItem media) {
    final instance = _instance;
    if (instance == null) return media;
    for (final sink in instance._lineSinks) {
      sink.onMediaItem(media);
    }
    return instance._attachLyricInfo(media);
  }

  static void init() {
    if (LyricsIntegration.valuesForPlatform.isEmpty) return;
    settings.lyricsIntegrations.addListener(_onSettingsChanged);
    _onSettingsChanged(isInit: true);
  }

  static void _onSettingsChanged({bool isInit = false}) {
    // -- a backup or sync from another platform can bring integrations that don't exist here
    final enabled = settings.lyricsIntegrations.value.where((e) => e.isForCurrentPlatform).toSet();
    final current = _instance;
    if (enabled.isEmpty) {
      current?._dispose();
      _instance = null;
      return;
    }
    if (current != null) {
      current._apply(enabled);
      return;
    }
    final created = LyricsIntegrations._();
    _instance = created;
    created._apply(enabled);
    if (!isInit) created._loadLyricsIfViewsDisabled();
  }

  LyricsIntegrations._() {
    Lyrics.inst.currentLyricsLRC.addListener(_onLyricsChanged);
    settings.visualDelayMS.addListener(_onLyricsChanged);
    Player.inst.currentItem.addListener(_onCurrentItemChanged);
  }

  void _dispose() {
    Lyrics.inst.currentLyricsLRC.removeListener(_onLyricsChanged);
    settings.visualDelayMS.removeListener(_onLyricsChanged);
    Player.inst.currentItem.removeListener(_onCurrentItemChanged);
    for (final sink in _lineSinks) {
      sink.dispose();
    }
    _lineSinks.clear();
    _lines = const [];
    _lineResolver = LrcLineResolver.empty;
    _refreshPositionListening();
    _refreshLyricInfo(null);
  }

  bool _lyricInfoEnabled = false;
  final _lineSinks = <_LyricsLineSink>[];
  bool _listeningPosition = false;

  String? _lyricInfoMediaId;
  _LyricInfoLanes? _lyricInfoLanes;

  /// one line per [_lineResolver] slot, background vocals and same-timestamp translations are dropped.
  List<LrcLine> _lines = const [];
  LrcLineResolver _lineResolver = LrcLineResolver.empty;
  int? _sentSlot;
  bool _isShowingLine = false;

  MediaItem _attachLyricInfo(MediaItem media) {
    final lanes = _lyricInfoLanes;
    if (lanes == null || media.id != _lyricInfoMediaId) return media;
    return _withLyricInfo(media, lanes);
  }

  static MediaItem _withLyricInfo(MediaItem media, _LyricInfoLanes? lanes) {
    final extras = <String, dynamic>{...?media.extras};
    if (lanes == null) {
      extras.remove(NowPlayingExtras.lyricInfo);
    } else {
      extras[NowPlayingExtras.lyricInfo] = lanes.toJsonString(media);
    }
    return media.copyWith(extras: extras);
  }

  void _apply(Set<LyricsIntegration> enabled) {
    _lyricInfoEnabled = enabled.contains(LyricsIntegration.lyricInfo);
    _syncLineSinks(enabled);
    _onLyricsChanged();
  }

  void _syncLineSinks(Set<LyricsIntegration> enabled) {
    _lineSinks.removeWhere((sink) {
      if (enabled.contains(sink.type)) return false;
      sink.dispose();
      return true;
    });
    for (final type in enabled) {
      if (_lineSinks.any((sink) => sink.type == type)) continue;
      final sink = _createLineSink(type);
      if (sink != null) _lineSinks.add(sink);
    }
  }

  static _LyricsLineSink? _createLineSink(LyricsIntegration type) => switch (type) {
    LyricsIntegration.lyricInfo => null,
    LyricsIntegration.superLyric => const _SuperLyricSink(),
    LyricsIntegration.flymeTicker => const _FlymeTickerSink(),
    LyricsIntegration.menuBar => const _MenuBarSink(),
    LyricsIntegration.liveActivity => _LiveActivitySink(),
  };

  /// published items come through [prepareMediaItem], only the queue being cleared needs telling.
  void _onCurrentItemChanged() {
    if (Player.inst.currentItem.value != null) return;
    for (final sink in _lineSinks) {
      sink.onMediaCleared();
    }
  }

  void _dropLineSink(_LyricsLineSink sink) {
    if (!_lineSinks.remove(sink)) return;
    sink.dispose();
    _refreshPositionListening();
  }

  void _loadLyricsIfViewsDisabled() {
    if (settings.enableLyrics.value || settings.enableSimpleLyricsLine.value) return;
    final item = Player.inst.currentItem.value;
    if (item != null) Lyrics.inst.updateLyrics(item);
  }

  void _onLyricsChanged() {
    final lrc = Lyrics.inst.currentLyricsLRC.value;
    if (lrc == null) {
      _lines = const [];
      _lineResolver = LrcLineResolver.empty;
    } else {
      _loadPrimaryLines(lrc);
    }
    _sentSlot = null;

    final lyricInfoLanes = _lyricInfoEnabled && _lines.isNotEmpty ? _LyricInfoLanes.fromLines(_lines) : null;
    _refreshLyricInfo(lyricInfoLanes);

    _refreshPositionListening();
    if (_listeningPosition) {
      _onPosition();
    } else {
      _showLine(null, 0, 0);
    }
  }

  void _refreshLyricInfo(_LyricInfoLanes? lanes) {
    final item = Player.inst.currentItem.value;
    _lyricInfoMediaId = item?.execute(
      selectable: (finalItem) => finalItem.toMediaItemId(),
      youtubeID: (finalItem) => finalItem.toMediaItemId(),
    );
    _lyricInfoLanes = lanes;

    final media = Player.inst.currentMediaItem;
    if (media == null || media.id != _lyricInfoMediaId) return;
    final hasLyricInfo = media.extras?.containsKey(NowPlayingExtras.lyricInfo) == true;
    if (lanes == null && !hasLyricInfo) return;
    final updatedMedia = _withLyricInfo(media, lanes);
    Player.inst.republishMediaItem(updatedMedia);
  }

  void _loadPrimaryLines(Lrc lrc) {
    final stretchMultiplier = Lyrics.inst.getStretchMultiplier(lrc);
    final visualDelay = Duration(milliseconds: settings.visualDelayMS.value);
    final info = lrc.forUiDisplay(stretchMultiplier, extraOffsetDuration: visualDelay);
    final uiLines = info.uiLyricsLines;
    final lineResolver = info.lineResolver;
    _lines = lineResolver.lineIndices.map((index) => uiLines[index]).toFixedList();
    _lineResolver = lineResolver;
  }

  void _refreshPositionListening() {
    final listen = _lineSinks.isNotEmpty && _lines.isNotEmpty;
    if (listen == _listeningPosition) return;
    _listeningPosition = listen;
    if (listen) {
      Player.inst.nowPlayingPosition.addListener(_onPosition);
      Player.inst.playWhenReady.addListener(_onPlayWhenReadyChanged);
    } else {
      Player.inst.nowPlayingPosition.removeListener(_onPosition);
      Player.inst.playWhenReady.removeListener(_onPlayWhenReadyChanged);
    }
  }

  void _onPlayWhenReadyChanged() {
    if (Player.inst.playWhenReady.value) {
      _onPosition();
    } else {
      _sentSlot = null;
      _showLine(null, 0, 0);
    }
  }

  void _onPosition() {
    if (!Player.inst.playWhenReady.value) return;
    final positionMS = Player.inst.nowPlayingPosition.value;
    final slot = _lineResolver.slotAt(positionMS);
    if (slot == _sentSlot) return;
    _sentSlot = slot;
    if (slot < 0) {
      _showLine(null, 0, 0);
      return;
    }

    final lines = _lines;
    final line = lines[slot];
    final text = line.readableText;
    final startMS = line.timestamp.inMilliseconds;
    final nextSlot = slot + 1;
    final durationMS = Player.inst.currentItemDuration.value?.inMilliseconds ?? startMS;
    final endMS = nextSlot < lines.length ? lines[nextSlot].timestamp.inMilliseconds : durationMS;
    _showLine(text.isEmpty ? null : text, startMS, endMS);
  }

  void _showLine(String? text, int startMS, int endMS) {
    if (text == null && !_isShowingLine) return;
    _isShowingLine = text != null;
    final media = Player.inst.currentMediaItem;
    for (final sink in _lineSinks) {
      _sendToSink(sink, media, text, startMS, endMS);
    }
  }

  Future<void> _sendToSink(_LyricsLineSink sink, MediaItem? media, String? text, int startMS, int endMS) async {
    final isAvailable = await sink.send(media, text, startMS, endMS);
    if (!isAvailable) _dropLineSink(sink);
  }
}

abstract class _LyricsLineSink {
  const _LyricsLineSink();

  LyricsIntegration get type;

  /// null [text] clears. resolves to false when the target isn't available on this system.
  Future<bool> send(MediaItem? media, String? text, int startMS, int endMS);

  /// every media item published, including tracks without lyrics.
  void onMediaItem(MediaItem media) {}

  void onMediaCleared() {}

  void dispose();
}

class _SuperLyricSink extends _LyricsLineSink {
  const _SuperLyricSink();

  @override
  LyricsIntegration get type => LyricsIntegration.superLyric;

  @override
  Future<bool> send(MediaItem? media, String? text, int startMS, int endMS) {
    return NamidaChannel.inst.sendSuperLyric(
      title: media?.title,
      artist: media?.artist,
      album: media?.album,
      text: text,
      startMS: startMS,
      endMS: endMS,
    );
  }

  @override
  void dispose() {
    send(null, null, 0, 0);
    NamidaChannel.inst.releaseSuperLyric();
  }
}

class _FlymeTickerSink extends _LyricsLineSink {
  const _FlymeTickerSink();

  @override
  LyricsIntegration get type => LyricsIntegration.flymeTicker;

  @override
  Future<bool> send(MediaItem? media, String? text, int startMS, int endMS) {
    return AudioService.setNotificationTicker(text);
  }

  @override
  void dispose() {
    AudioService.setNotificationTicker(null);
  }
}

/// the lock screen & dynamic island keep showing the playing item, the line follows the lyrics.
/// started by playback only, a paused item restored at launch stays off the lock screen.
class _LiveActivitySink extends _LyricsLineSink {
  _LiveActivitySink() {
    Player.inst.playWhenReady.addListener(_onPlayWhenReadyChanged);
    _onPlayWhenReadyChanged();
  }

  String? _shownTitle;
  String? _shownArtist;

  /// kept across items, the next item's lyrics can be loaded before the item itself is published.
  String? _line;

  @override
  LyricsIntegration get type => LyricsIntegration.liveActivity;

  @override
  Future<bool> send(MediaItem? media, String? text, int startMS, int endMS) async {
    final widgets = HomeWidgetController.instance;
    if (widgets == null) return false;
    _line = text;
    if (media == null) {
      await _end(widgets);
      return true;
    }
    return _show(widgets, media);
  }

  void _onPlayWhenReadyChanged() {
    if (_shownTitle != null || !Player.inst.playWhenReady.value) return;
    final media = Player.inst.currentMediaItem;
    if (media != null) onMediaItem(media);
  }

  @override
  void onMediaCleared() {
    final widgets = HomeWidgetController.instance;
    if (widgets != null) _end(widgets);
  }

  /// also catches the same item republished with its info, ex: a youtube video whose title arrives later.
  @override
  void onMediaItem(MediaItem media) {
    if (media.title == _shownTitle && media.artist == _shownArtist) return;
    final widgets = HomeWidgetController.instance;
    if (widgets != null) _show(widgets, media);
  }

  Future<bool> _show(HomeWidgets widgets, MediaItem media) async {
    // -- a late publish or line after the queue was cleared
    if (Player.inst.currentItem.value == null) return true;
    final isShown = _shownTitle != null;
    if (!isShown && !Player.inst.playWhenReady.value) return true;
    final title = media.title;
    final artist = media.artist;
    _shownTitle = title;
    _shownArtist = artist;
    return widgets.updateLiveActivity(title: title, artist: artist, line: _line);
  }

  Future<void> _end(HomeWidgets widgets) {
    _shownTitle = null;
    _shownArtist = null;
    _line = null;
    return widgets.endLiveActivity();
  }

  @override
  void dispose() {
    Player.inst.playWhenReady.removeListener(_onPlayWhenReadyChanged);
    HomeWidgetController.instance?.endLiveActivity();
  }
}

class _MenuBarSink extends _LyricsLineSink {
  const _MenuBarSink();

  @override
  LyricsIntegration get type => LyricsIntegration.menuBar;

  @override
  Future<bool> send(MediaItem? media, String? text, int startMS, int endMS) async {
    final tray = TrayController.instance;
    if (tray == null) return false;
    await tray.setLyricsLine(text);
    return true;
  }

  @override
  void dispose() {
    TrayController.instance?.setLyricsLine(null);
  }
}

class _LyricInfoLanes {
  final String lyric;
  final String? rawLyric;

  const _LyricInfoLanes(this.lyric, this.rawLyric);

  factory _LyricInfoLanes.fromLines(List<LrcLine> lines) {
    final hasWords = lines.any((line) => line.parts?.isNotEmpty == true);
    final lyric = StringBuffer();
    final rawLyric = hasWords ? StringBuffer() : null;
    for (final line in lines) {
      final text = line.readableText;
      if (text.isEmpty) continue;
      final lineTimestampText = LrcLine.formatTimestamp(line.timestamp);
      final lineTag = '[$lineTimestampText]';
      lyric
        ..write(lineTag)
        ..writeln(text);
      if (rawLyric == null) continue;
      rawLyric.write(lineTag);
      final parts = line.parts;
      if (parts == null || parts.isEmpty) {
        rawLyric.writeln(text);
        continue;
      }
      for (final part in parts) {
        final partTimestampText = LrcLine.formatTimestamp(part.startTimestamp);
        rawLyric
          ..write('<$partTimestampText>')
          ..write(part.lyrics);
      }
      final endTimestampText = LrcLine.formatTimestamp(parts.last.endTimestamp);
      rawLyric.writeln('<$endTimestampText>');
    }
    return _LyricInfoLanes(lyric.toString(), rawLyric?.toString());
  }

  String toJsonString(MediaItem media) {
    return jsonEncode({
      'songName': media.title,
      'artist': media.artist,
      'album': media.album,
      'songId': media.id,
      'lyricType': 0,
      'lyric': lyric,
      'rawLyric': ?rawLyric,
      'noLyric': false,
    });
  }
}
