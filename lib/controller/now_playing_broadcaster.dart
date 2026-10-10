// by claude
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';

import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';

/// fans out playback changes to whatever the user enabled: android broadcasts (tasker & co),
/// scrobblers speaking the sls api, and a webhook url. nothing is built while no sink is active.
class NowPlayingBroadcaster {
  static final inst = NowPlayingBroadcaster._();

  NowPlayingBroadcaster._() {
    settings.nowPlayingBroadcast.addListener(_rebuildSinks);
    settings.scrobblerBroadcast.addListener(_rebuildSinks);
    settings.webhookUrl.addListener(_rebuildSinks);
    settings.webhookEvents.addListener(_rebuildSinks);
    settings.reportPlaybackToServers.addListener(_rebuildSinks);
    settings.directoriesToScan.addListener(_rebuildSinks);
    _rebuildSinks();
  }

  final _sinks = <_NowPlayingSink>[];
  MediaItem? _lastMedia;
  final _serverReporter = ServerNowPlayingReporter();

  void _rebuildSinks() {
    _sinks.clear();
    if (NamidaFeaturesVisibility.showAndroidIntegrations) {
      if (settings.nowPlayingBroadcast.value) _sinks.add(const _NamidaBroadcastSink());
      if (settings.scrobblerBroadcast.value) _sinks.add(const _ScrobblerBroadcastSink());
    }
    final webhookUri = parseWebhookUrl(settings.webhookUrl.value);
    if (webhookUri != null) _sinks.add(_WebhookSink(webhookUri, settings.webhookEvents.value));
    if (_shouldReportToServers()) {
      _sinks.add(_ServerReportSink(_serverReporter));
    } else {
      _serverReporter.end();
    }
  }

  bool _shouldReportToServers() {
    if (!settings.reportPlaybackToServers.value) return false;
    return settings.directoriesToScan.value.any((d) => d.type.check(DirectoryIndexTypeTag.reportsPlayback));
  }

  static Uri? parseWebhookUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) return null;
    final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
    return isHttp ? uri : null;
  }

  void onItemChanged(MediaItem media, {required bool isPlaying, required int positionMS}) {
    _lastMedia = media;
    _send(media, WebhookEvent.trackChanged, isPlaying, positionMS);
  }

  void onPlayingChanged(bool isPlaying, {required int positionMS}) {
    final media = _lastMedia;
    if (media == null) return;
    final type = isPlaying ? WebhookEvent.play : WebhookEvent.pause;
    _send(media, type, isPlaying, positionMS);
  }

  void _send(MediaItem media, WebhookEvent type, bool isPlaying, int positionMS) {
    if (_sinks.isEmpty) return;
    final event = _NowPlayingEvent(media, type, isPlaying, positionMS);
    for (final sink in _sinks) {
      sink.send(event);
    }
  }
}

abstract class _NowPlayingSink {
  const _NowPlayingSink();

  void send(_NowPlayingEvent event);
}

class _NamidaBroadcastSink extends _NowPlayingSink {
  const _NamidaBroadcastSink();

  static const _kActionMetaChanged = 'com.msob7y.namida.metachanged';
  static const _kActionPlayStateChanged = 'com.msob7y.namida.playstatechanged';

  @override
  void send(_NowPlayingEvent event) {
    final action = event.type == WebhookEvent.trackChanged ? _kActionMetaChanged : _kActionPlayStateChanged;
    final extras = event.toJson();
    NamidaChannel.inst.sendBroadcast(action, extras);
  }
}

/// simple last.fm scrobbler api, also accepted by pano scrobbler.
class _ScrobblerBroadcastSink extends _NowPlayingSink {
  const _ScrobblerBroadcastSink();

  static const _kAction = 'com.adam.aslfms.notify.playstatechanged';
  static const _kPackages = ['com.adam.aslfms', 'com.arn.scrobble'];

  static const _kStateStart = 0;
  static const _kStateResume = 1;
  static const _kStatePause = 2;

  @override
  void send(_NowPlayingEvent event) {
    final isNewTrack = event.type == WebhookEvent.trackChanged;
    // -- a track set while paused reaches the scrobbler through the resume that follows, it carries the same metadata.
    if (isNewTrack && !event.isPlaying) return;
    final media = event.media;
    final state = switch (event.type) {
      WebhookEvent.trackChanged => _kStateStart,
      WebhookEvent.play => _kStateResume,
      WebhookEvent.pause => _kStatePause,
    };
    final durationSeconds = media.duration?.inSeconds ?? 0;
    final mbTrackId = media.extras?[NowPlayingExtras.mbTrackId];
    final extras = <String, Object?>{
      'app-name': 'Namida',
      'app-package': 'com.msob7y.namida',
      'state': state,
      'artist': media.artist ?? '',
      'album': media.album ?? '',
      'track': media.title,
      'duration': durationSeconds,
      'source': 'P',
      'mbid': ?mbTrackId,
    };
    NamidaChannel.inst.sendBroadcast(_kAction, extras, packages: _kPackages);
  }
}

class _ServerReportSink extends _NowPlayingSink {
  final ServerNowPlayingReporter reporter;

  const _ServerReportSink(this.reporter);

  @override
  void send(_NowPlayingEvent event) {
    switch (event.type) {
      case WebhookEvent.trackChanged:
        final media = event.media;
        final path = media.extras?[NowPlayingExtras.path] as String?;
        final durationMS = media.duration?.inMilliseconds;
        reporter.onItemChanged(path, isPlaying: event.isPlaying, positionMS: event.positionMS, durationMS: durationMS);
      case WebhookEvent.play || WebhookEvent.pause:
        reporter.onPlayingChanged(event.isPlaying, positionMS: event.positionMS);
    }
  }
}

class _WebhookSink extends _NowPlayingSink {
  final Uri uri;
  final Set<WebhookEvent> events;

  _WebhookSink(this.uri, this.events);

  bool _didLogError = false;

  @override
  void send(_NowPlayingEvent event) {
    if (!events.contains(event.type)) return;
    final body = event.toJson();
    _post(body);
  }

  Future<void> _post(Map<String, dynamic> body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(const Duration(seconds: 15));
      await response.drain<void>();
    } catch (e, st) {
      if (!_didLogError) {
        _didLogError = true;
        logger.error('webhook post failed', e: e, st: st);
      }
    } finally {
      client.close(force: true);
    }
  }
}

/// keys of [MediaItem.extras], read by media controllers directly and reused in broadcasts & webhooks.
/// identifiers from the file tags sit next to them under their picard names (`MUSICBRAINZ_TRACKID`, `ISRC`, ...).
class NowPlayingExtras {
  static const path = 'path';
  static const videoId = 'videoId';
  static const queueIndex = 'queueIndex';
  static const queueLength = 'queueLength';
  static const mbTrackId = 'MUSICBRAINZ_TRACKID';

  /// colorOS lyrics json, too big for broadcasts & webhooks.
  static const lyricInfo = 'lyricInfo';
}

class _NowPlayingEvent {
  final MediaItem media;
  final WebhookEvent type;
  final bool isPlaying;
  final int positionMS;

  _NowPlayingEvent(this.media, this.type, this.isPlaying, this.positionMS);

  Map<String, dynamic>? _json;

  Map<String, dynamic> toJson() {
    return _json ??= {
      'event': type.name,
      'playing': isPlaying,
      'positionMS': positionMS,
      'title': media.title,
      'artist': media.artist,
      'album': media.album,
      'genre': media.genre,
      'durationMS': media.duration?.inMilliseconds,
      ...?media.extras,
    }..remove(NowPlayingExtras.lyricInfo);
  }
}
