// by claude
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:crypto/crypto.dart';

import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

part 'now_playing_broadcaster.discord.dart';
part 'now_playing_broadcaster.discord_gateway.dart';

/// fans out playback changes to whatever the user enabled: android broadcasts (tasker & co),
/// server playback reports, a webhook url and discord presence. nothing is built while no sink is active.
class NowPlayingBroadcaster {
  static final inst = NowPlayingBroadcaster._();

  NowPlayingBroadcaster._() {
    settings.nowPlayingBroadcast.addListener(_rebuildSinks);
    settings.webhookUrl.addListener(_rebuildSinks);
    settings.webhookEvents.addListener(_rebuildSinks);
    settings.reportPlaybackToServers.addListener(_rebuildSinks);
    settings.directoriesToScan.addListener(_rebuildSinks);
    settings.discordPresence.addListener(_rebuildSinks);
    _rebuildSinks();
  }

  final _sinks = <_NowPlayingSink>[];
  MediaItem? _lastMedia;
  final _serverReporter = ServerNowPlayingReporter();
  _DiscordPresenceSink? _discordSink;

  void _rebuildSinks() {
    _sinks.clear();
    if (NamidaFeaturesVisibility.showAndroidIntegrations && settings.nowPlayingBroadcast.value) {
      _sinks.add(const _NamidaBroadcastSink());
    }
    final webhookUri = parseWebhookUrl(settings.webhookUrl.value);
    if (webhookUri != null) _sinks.add(_WebhookSink(webhookUri, settings.webhookEvents.value));
    if (_shouldReportToServers()) {
      _sinks.add(_ServerReportSink(_serverReporter));
    } else {
      _serverReporter.end();
    }
    if (settings.discordPresence.value) {
      final discordSink = _discordSink ??= _createDiscordSink();
      _sinks.add(discordSink);
    } else {
      _discordSink?.close();
      _discordSink = null;
    }
  }

  _DiscordPresenceSink _createDiscordSink() {
    final sink = _DiscordPresenceSink();
    final media = _lastMedia;
    if (media != null) {
      final isPlaying = Player.inst.isPlaying.value;
      final positionMS = Player.inst.nowPlayingPosition.value;
      sink.send(_NowPlayingEvent(media, WebhookEvent.trackChanged, isPlaying, positionMS));
    }
    return sink;
  }

  RxBaseCore<DiscordPresenceStatus> get discordStatus => _DiscordPresenceReport.inst.status;
  RxBaseCore<DiscordAccount?> get discordAccount => _DiscordPresenceReport.inst.account;
  RxBaseCore<bool> get isDiscordSharing => _DiscordPresenceReport.inst.isSharing;

  /// only mobile logs in, desktop goes through the discord app.
  bool get discordRequiresLogin => _DiscordPresenceTransport.usesGateway;

  /// false when the login was cancelled, throws when it failed.
  Future<bool> ensureDiscordLogin() async {
    if (!_DiscordPresenceTransport.usesGateway) return true;
    final oauth = _DiscordOAuth.inst;
    final hasLogin = await oauth.hasLogin();
    if (hasLogin) return true;
    final didLogIn = await oauth.logIn();
    if (didLogIn) _discordSink?.resend();
    return didLogIn;
  }

  Future<void> logOutOfDiscord() async {
    settings.discordPresence.save(false);
    await _DiscordOAuth.inst.logOut();
  }

  void refreshDiscordStatus() => _discordSink?.probe();

  bool handleDiscordAuthRedirect(String link) => _DiscordOAuth.inst.handleRedirect(link);

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

  void onSeek(int positionMS) => _discordSink?.onSeek(positionMS);

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
class NowPlayingExtras {
  static const path = 'path';
  static const videoId = 'videoId';
  static const queueIndex = 'queueIndex';
  static const queueLength = 'queueLength';

  /// file tag ids as `org.musicbrainz.MUSICBRAINZ_TRACKID`, the keys proposed in https://github.com/OxygenCobalt/Auxio/issues/1268.
  /// broadcasts & webhooks drop the prefix.
  static const tagIdPrefix = 'org.musicbrainz.';

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
    final extras = media.extras;
    return _json ??= {
      'event': type.name,
      'playing': isPlaying,
      'positionMS': positionMS,
      'title': media.title,
      'artist': media.artist,
      'album': media.album,
      'genre': media.genre,
      'durationMS': media.duration?.inMilliseconds,
      if (extras != null)
        for (final e in extras.entries)
          if (e.key != NowPlayingExtras.lyricInfo) _toJsonKey(e.key): e.value,
    };
  }

  /// tasker can't name variables with dots.
  static String _toJsonKey(String key) {
    const prefix = NowPlayingExtras.tagIdPrefix;
    return key.startsWith(prefix) ? key.substring(prefix.length) : key;
  }
}

class DiscordAccount {
  final String id;
  final String name;
  final String avatarUrl;

  const DiscordAccount({required this.id, required this.name, required this.avatarUrl});

  factory DiscordAccount.fromUserJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final username = json['username'] as String;
    final displayName = json['global_name'] as String?;
    final avatarHash = json['avatar'] as String?;
    final discriminator = json['discriminator'] as String?;
    final avatarUrl = avatarHash == null ? _getDefaultAvatarUrl(id, discriminator) : 'https://cdn.discordapp.com/avatars/$id/$avatarHash.png?size=128';
    return DiscordAccount(id: id, name: displayName ?? username, avatarUrl: avatarUrl);
  }

  factory DiscordAccount.fromJson(Map<String, dynamic> json) {
    return DiscordAccount(id: json['id'] as String, name: json['name'] as String, avatarUrl: json['avatarUrl'] as String);
  }

  /// discord's own fallback for accounts without an avatar, legacy accounts still have a discriminator.
  static String _getDefaultAvatarUrl(String id, String? discriminator) {
    final legacyDiscriminator = int.tryParse(discriminator ?? '') ?? 0;
    if (legacyDiscriminator != 0) return 'https://cdn.discordapp.com/embed/avatars/${legacyDiscriminator % 5}.png';
    final index = (int.parse(id) >> 22) % 6;
    return 'https://cdn.discordapp.com/embed/avatars/$index.png';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
  };

  @override
  bool operator ==(Object other) => other is DiscordAccount && other.id == id && other.name == name && other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, name, avatarUrl);
}
