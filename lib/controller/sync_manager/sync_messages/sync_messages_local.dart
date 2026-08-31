part of '../sync_manager.dart';

class HistoryListensMessage extends BaseMessage {
  final Iterable<TrackWithDate> tracks;

  const HistoryListensMessage({
    required this.tracks,
    required super.messageInfo,
  }) : super(MessageType.historyListens);

  factory HistoryListensMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return HistoryListensMessage(
      tracks: (map['tracks'] as List).map((e) => TrackWithDate.fromJson(e)),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'tracks': tracks.map((e) => e.toJson()).toFixedList(),
  };

  @override
  FutureOr<void> executeOnReceived() {
    final resolved = SyncPathResolver.resolveTracksWithDates(messageInfo.senderDeviceId, tracks);
    if (SyncUtils.kAllowModification) {
      return HistoryController.inst.addTracksToHistoryImportPreventDuplicates(resolved);
    } else {
      snackyy(message: 'Importing ${resolved.length} listen | ${resolved.take(10).map((e) => e.track).toFixedList()}');
    }
  }
}

/// Fingerprints of the sender's tracks database. The receiver uses them to
/// translate paths into its own local paths. See [SyncPathResolver].
class TracksDbFingerprintsMessage extends BaseMessage {
  final List<dynamic> entries;

  const TracksDbFingerprintsMessage({
    required this.entries,
    required super.messageInfo,
  }) : super(MessageType.tracksDbFingerprints);

  static Future<TracksDbFingerprintsMessage> createForCurrentDevice() async {
    return TracksDbFingerprintsMessage(
      entries: await SyncPathResolver.buildLocalEntries(),
      messageInfo: await SyncUtils.createMessageInfo(.manifest),
    );
  }

  factory TracksDbFingerprintsMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return TracksDbFingerprintsMessage(
      entries: map['e'] as List,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'e': entries,
  };

  @override
  String toRawInfo() => 'TracksDbFingerprints(${entries.length} tracks)';

  @override
  FutureOr<void> executeOnReceived() {
    SyncPathResolver.buildForDevice(messageInfo.senderDeviceId, entries);
  }
}

class PlayerQueueMessage extends BaseMessage {
  final Iterable<dynamic> items;
  final int queueModifiedTime;
  final int currentIndex;

  const PlayerQueueMessage({
    required this.items,
    required this.queueModifiedTime,
    required this.currentIndex,
    required super.messageInfo,
  }) : super(MessageType.playerQueue);

  static Future<PlayerQueueMessage?> createForCurrentDevice() async {
    final payload = QueueController.inst.buildPlayerQueueSyncPayload();
    if (payload == null) return null;
    return PlayerQueueMessage(
      items: payload.$1,
      queueModifiedTime: payload.$2,
      currentIndex: payload.$3,
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
  }

  factory PlayerQueueMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return PlayerQueueMessage(
      items: map['items'] as List,
      queueModifiedTime: map['qmt'] as int? ?? 0,
      currentIndex: map['i'] as int? ?? 0,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'items': items.toFixedList(),
    'qmt': queueModifiedTime,
    'i': currentIndex,
  };

  @override
  String toRawInfo() => 'PlayerQueue(${items.length} items @$currentIndex)';

  @override
  FutureOr<void> executeOnReceived() async {
    if (!SyncUtils.kAllowModification) {
      snackyy(message: 'Importing player queue of ${items.length} items');
      return;
    }
    final senderDeviceId = messageInfo.senderDeviceId;
    await QueueController.inst.importPlayerQueue(items, queueModifiedTime, currentIndex, senderDeviceId);
    // -- a playback state may have arrived earlier & requested this queue, apply it now
    final pendingPlayback = PlaybackStateMessage._pendingByDevice.remove(senderDeviceId);
    if (pendingPlayback != null && pendingPlayback.queueModifiedTime == queueModifiedTime) {
      await pendingPlayback._apply();
    }
  }
}

class PlaybackStateMessage extends BaseMessage {
  final int queueModifiedTime;
  final int queueIndex;
  final int positionMS;
  final int? durationMS;
  final bool isPlaying;

  const PlaybackStateMessage({
    required this.queueModifiedTime,
    required this.queueIndex,
    required this.positionMS,
    required this.durationMS,
    required this.isPlaying,
    required super.messageInfo,
  }) : super(MessageType.playback);

  /// received playback states waiting for their matching player queue to be imported first.
  static final _pendingByDevice = <String, PlaybackStateMessage>{};

  static const _kMinSeekDifferenceMS = 1000;

  static Future<PlaybackStateMessage?> createForCurrentDevice() async {
    if (Player.inst.currentQueue.value.isEmpty) return null;
    return PlaybackStateMessage(
      queueModifiedTime: QueueController.inst.playerQueueModifiedTime,
      queueIndex: Player.inst.currentIndex.value,
      positionMS: Player.inst.nowPlayingPosition.value,
      durationMS: Player.inst.currentItemDuration.value?.inMilliseconds,
      isPlaying: Player.inst.isPlaying.value,
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
  }

  factory PlaybackStateMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return PlaybackStateMessage(
      queueModifiedTime: map['qmt'] as int? ?? 0,
      queueIndex: map['i'] as int? ?? 0,
      positionMS: map['pos'] as int? ?? 0,
      durationMS: map['dur'] as int?,
      isPlaying: map['pl'] as bool? ?? false,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'qmt': queueModifiedTime,
    'i': queueIndex,
    'pos': positionMS,
    'dur': ?durationMS,
    'pl': isPlaying,
  };

  @override
  String toRawInfo() => 'PlaybackState(@$queueIndex, ${positionMS}ms, playing: $isPlaying)';

  @override
  FutureOr<void> executeOnReceived() async {
    if (!SyncUtils.kAllowModification) {
      snackyy(message: 'Importing playback state @$queueIndex (${positionMS}ms, playing: $isPlaying)');
      return;
    }
    if (QueueController.inst.playerQueueModifiedTime != queueModifiedTime) {
      // -- our queue is not the sender's queue, request theirs first
      // -- & re-apply this state after it gets imported.
      final senderDeviceId = messageInfo.senderDeviceId;
      _pendingByDevice[senderDeviceId] = this;
      final msg = RequestMessage(
        msgRequestType: .playerQueue,
        messageInfo: await SyncUtils.createMessageInfo(.manifest),
        batchRef: null,
      );
      await SyncDiscovery.sendMessage(msg, senderDeviceId);
      return;
    }
    await _apply();
  }

  Future<void> _apply() async {
    final player = Player.inst;
    if (queueIndex >= 0 && queueIndex < player.currentQueue.value.length && player.currentIndex.value != queueIndex) {
      await player.skipToQueueItem(queueIndex);
    }
    final positionDiff = (player.nowPlayingPosition.value - positionMS).abs();
    if (positionDiff >= _kMinSeekDifferenceMS) {
      await player.seek(Duration(milliseconds: positionMS));
    }
    if (isPlaying != player.isPlaying.value) {
      isPlaying ? await player.play() : await player.pause();
    }
  }
}

class TrackStatsMessage extends BaseMessage {
  final Iterable<TrackStats> stats;

  const TrackStatsMessage({
    required this.stats,
    required super.messageInfo,
  }) : super(MessageType.trackStats);

  static Future<TrackStatsMessage> createForCurrentDevice() async {
    return TrackStatsMessage(
      stats: Indexer.inst.trackStatsMap.value.values,
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
  }

  static TrackStats? _tryParse(dynamic map) {
    try {
      return TrackStats.fromJson((map as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  factory TrackStatsMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return TrackStatsMessage(
      stats: (map['e'] as List).map(_tryParse).nonNulls,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'e': stats.map((e) => e.toJson()).toFixedList(),
  };

  @override
  String toRawInfo() => 'TrackStats(${stats.length} entries)';

  @override
  FutureOr<void> executeOnReceived() {
    if (SyncUtils.kAllowModification) {
      return Indexer.inst.importTrackStats(stats, messageInfo.senderDeviceId);
    } else {
      snackyy(message: 'Importing ${stats.length} track stats');
    }
  }
}

class FavouritesMessage extends BaseMessage {
  final Iterable<TrackWithDate> tracks;

  const FavouritesMessage({
    required this.tracks,
    required super.messageInfo,
  }) : super(MessageType.favourites);

  factory FavouritesMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return FavouritesMessage(
      tracks: (map['tracks'] as List).map((e) => TrackWithDate.fromJson(e)),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'tracks': tracks.map((e) => e.toJson()).toFixedList(),
  };

  @override
  String toRawInfo() => 'Favourites(${tracks.length} tracks)';

  @override
  FutureOr<void> executeOnReceived() async {
    final resolved = SyncPathResolver.resolveTracksWithDates(messageInfo.senderDeviceId, tracks);
    if (SyncUtils.kAllowModification) {
      await PlaylistController.inst.importTracksToPlaylist(
        PlaylistController.inst.favouritesPlaylist.value,
        resolved,
      );
    } else {
      snackyy(message: 'Importing ${resolved.length} favourites | ${resolved.take(10).map((e) => e.track).toFixedList()}');
    }
  }
}

class LatestPlayedForSourceMessage extends BaseMessage {
  final Iterable<MapEntry<String, Map<String, dynamic>>> entries;

  const LatestPlayedForSourceMessage({
    required this.entries,
    required super.messageInfo,
  }) : super(MessageType.latestPlayedForSource);

  static Future<LatestPlayedForSourceMessage> createForCurrentDevice() async {
    return LatestPlayedForSourceMessage(
      entries: QueueController.latestPlayedForSourceManager.buildSyncEntries(),
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
  }

  static MapEntry<String, Map<String, dynamic>>? _tryParse(dynamic pair) {
    try {
      final list = pair as List;
      return MapEntry(list[0] as String, (list[1] as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  factory LatestPlayedForSourceMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return LatestPlayedForSourceMessage(
      entries: (map['e'] as List).map(_tryParse).nonNulls,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'e': entries.map((e) => [e.key, e.value]).toFixedList(),
  };

  @override
  String toRawInfo() => 'LatestPlayedForSource(${entries.length} entries)';

  @override
  FutureOr<void> executeOnReceived() {
    if (SyncUtils.kAllowModification) {
      return QueueController.latestPlayedForSourceManager.import(entries, messageInfo.senderDeviceId);
    } else {
      snackyy(message: 'Importing ${entries.length} latest played entries');
    }
  }
}

class AudioConfigsMessage extends BaseMessage {
  final Iterable<MapEntry<String, PlayerConfig>> configs;

  const AudioConfigsMessage({
    required this.configs,
    required super.messageInfo,
  }) : super(MessageType.audioConfigs);

  static Future<AudioConfigsMessage> createForCurrentDevice() async {
    return AudioConfigsMessage(
      configs: Player.audioConfigs.buildSyncEntries(),
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
  }

  static MapEntry<String, PlayerConfig>? _tryParse(dynamic pair) {
    try {
      final list = pair as List;
      return MapEntry(list[0] as String, PlayerConfig.fromMap((list[1] as Map).cast<String, dynamic>()));
    } catch (_) {
      return null;
    }
  }

  factory AudioConfigsMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return AudioConfigsMessage(
      configs: (map['e'] as List).map(_tryParse).nonNulls,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'e': configs.map((e) => [e.key, e.value.toMap()]).toFixedList(),
  };

  @override
  String toRawInfo() => 'AudioConfigs(${configs.length} entries)';

  @override
  FutureOr<void> executeOnReceived() {
    if (SyncUtils.kAllowModification) {
      return Player.audioConfigs.import(configs, messageInfo.senderDeviceId);
    } else {
      snackyy(message: 'Importing ${configs.length} audio configs');
    }
  }
}

class SmartPlaylistsMessage extends BaseMessage {
  final Iterable<SmartPlaylist> playlists;

  const SmartPlaylistsMessage({
    required this.playlists,
    required super.messageInfo,
  }) : super(MessageType.smartPlaylists);

  static Future<SmartPlaylistsMessage> createForCurrentDevice() async {
    return SmartPlaylistsMessage(
      playlists: SmartPlaylistsController.inst.buildSyncEntries(),
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
  }

  static SmartPlaylist? _tryParse(dynamic map) {
    try {
      return SmartPlaylist.fromMap((map as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  factory SmartPlaylistsMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return SmartPlaylistsMessage(
      playlists: (map['e'] as List).map(_tryParse).nonNulls,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'e': playlists.map((e) => e.toMap()).toFixedList(),
  };

  @override
  String toRawInfo() => 'SmartPlaylists(${playlists.length} playlists)';

  @override
  FutureOr<void> executeOnReceived() {
    if (SyncUtils.kAllowModification) {
      return SmartPlaylistsController.inst.import(playlists);
    } else {
      snackyy(message: 'Importing ${playlists.length} smart playlists | ${playlists.map((e) => e.key).toFixedList()}');
    }
  }
}

class PlaylistsMessage extends BaseMessage {
  final Iterable<LocalPlaylist> playlists;

  const PlaylistsMessage({
    required this.playlists,
    required super.messageInfo,
  }) : super(MessageType.playlists);

  factory PlaylistsMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return PlaylistsMessage(
      playlists: (map['playlists'] as List).map((e) => LocalPlaylist.fromJson(e, TrackWithDate.fromJson, SortType.sortListFromJsonList)),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'playlists': playlists.map((e) => e.toJson((item) => item.toJson(), SortType.sortsToJson)).toFixedList(),
  };

  @override
  FutureOr<void> executeOnReceived() async {
    final senderDeviceId = messageInfo.senderDeviceId;
    final resolved = playlists.map(
      (pl) => pl.copyWith(tracks: SyncPathResolver.resolveTracksWithDates(senderDeviceId, pl.tracks).toList()),
    );
    if (SyncUtils.kAllowModification) {
      await PlaylistController.inst.importPlaylistsIfNewer(resolved);
    } else {
      snackyy(message: 'Importing ${resolved.length} playlists | ${resolved.map((e) => e.name).toFixedList()}');
    }
  }
}

class PlaylistsManifestResponseMessage extends BaseMessage {
  final List<PlaylistManifest> available;
  final SyncBatchRef? batchRef;

  const PlaylistsManifestResponseMessage({
    required super.messageInfo,
    required this.available,
    required this.batchRef,
  }) : super(MessageType.playlistsManifestResponse);

  factory PlaylistsManifestResponseMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return PlaylistsManifestResponseMessage(
      available: PlaylistManifest.fromMapAsList(map),
      batchRef: SyncBatchRef.fromMap(map['br']),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => PlaylistsManifestResponseMessageUtils.encodeToMap(available, batchRef);

  @override
  FutureOr<void> executeOnReceived() => PlaylistsManifestResponseMessageUtils.sendRequiredPlaylists(
    messageInfo: messageInfo,
    available: available,
    playlistsManager: PlaylistController.inst,
    tracksArePaths: true,
    batchRef: batchRef,
    createPlaylistsMessage: (playlistsToSend, createdMessageInfo) => PlaylistsMessage(
      playlists: playlistsToSend,
      messageInfo: createdMessageInfo,
    ),
  );
}
