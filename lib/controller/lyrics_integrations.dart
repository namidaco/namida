// by claude
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:lrc/lrc.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/now_playing_broadcaster.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';

/// pushes the playing lyrics to the system surfaces the user enabled. `lyricInfo` rides the media metadata once per track,
/// SuperLyric & the flyme ticker get one call per line. an instance only exists while at least one is on.
class LyricsIntegrations {
  static LyricsIntegrations? _instance;

  static bool get isActive => _instance != null;

  /// media items go through here before being published, to get the `lyricInfo` extra when available.
  static MediaItem prepareMediaItem(MediaItem media) => _instance?._attachLyricInfo(media) ?? media;

  static void init() {
    if (!NamidaFeaturesVisibility.showAndroidIntegrations) return;
    settings.lyricsIntegrations.addListener(_onSettingsChanged);
    _onSettingsChanged(isInit: true);
  }

  static void _onSettingsChanged({bool isInit = false}) {
    final enabled = settings.lyricsIntegrations.value;
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
  }

  void _dispose() {
    Lyrics.inst.currentLyricsLRC.removeListener(_onLyricsChanged);
    settings.visualDelayMS.removeListener(_onLyricsChanged);
    for (final sink in _lineSinks) {
      sink.dispose();
    }
    _lineSinks.clear();
    _lines = const [];
    _refreshPositionListening();
    _refreshLyricInfo(null);
  }

  bool _lyricInfoEnabled = false;
  final _lineSinks = <_LyricsLineSink>[];
  bool _listeningPosition = false;

  String? _lyricInfoMediaId;
  _LyricInfoLanes? _lyricInfoLanes;

  List<LrcLine> _lines = const [];
  int _scanIndex = -1;
  int? _sentIndex;
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
  };

  void _dropLineSink(_LyricsLineSink sink) {
    if (!_lineSinks.remove(sink)) return;
    _refreshPositionListening();
  }

  void _loadLyricsIfViewsDisabled() {
    if (settings.enableLyrics.value || settings.enableSimpleLyricsLine.value) return;
    final item = Player.inst.currentItem.value;
    if (item != null) Lyrics.inst.updateLyrics(item);
  }

  void _onLyricsChanged() {
    final lrc = Lyrics.inst.currentLyricsLRC.value;
    _lines = lrc == null ? const [] : _primaryLinesOf(lrc);
    _scanIndex = -1;
    _sentIndex = null;

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

  /// one line per timestamp, background vocals and same-timestamp translations are dropped.
  static List<LrcLine> _primaryLinesOf(Lrc lrc) {
    final stretchMultiplier = Lyrics.inst.getStretchMultiplier(lrc);
    final visualDelay = Duration(milliseconds: settings.visualDelayMS.value);
    final info = lrc.forUiDisplay(stretchMultiplier, extraOffsetDuration: visualDelay);
    final uiLines = info.uiLyricsLines;
    final lines = <LrcLine>[];
    for (final indices in info.highlightTimestampsMap.values) {
      for (final index in indices) {
        final line = uiLines[index];
        if (line.isBGLyrics) continue;
        lines.add(line);
        break;
      }
    }
    return lines;
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
      _sentIndex = null;
      _showLine(null, 0, 0);
    }
  }

  void _onPosition() {
    if (!Player.inst.playWhenReady.value) return;
    final lines = _lines;
    final position = Duration(milliseconds: Player.inst.nowPlayingPosition.value);

    int index = _scanIndex;
    if (index >= lines.length) index = -1;
    if (index >= 0 && lines[index].timestamp > position) index = -1;
    while (index + 1 < lines.length && lines[index + 1].timestamp <= position) {
      index++;
    }
    _scanIndex = index;

    if (index == _sentIndex) return;
    _sentIndex = index;
    if (index < 0) {
      _showLine(null, 0, 0);
      return;
    }

    final line = lines[index];
    final text = line.readableText;
    final startMS = line.timestamp.inMilliseconds;
    final nextIndex = index + 1;
    final durationMS = Player.inst.currentItemDuration.value?.inMilliseconds ?? startMS;
    final endMS = nextIndex < lines.length ? lines[nextIndex].timestamp.inMilliseconds : durationMS;
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
