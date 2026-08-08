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
    if (SyncUtils.kAllowModification) {
      return HistoryController.inst.addTracksToHistory(tracks);
    } else {
      snackyy(message: 'Importing ${tracks.length} listen | ${tracks.take(10).map((e) => e.track).toFixedList()}');
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
    if (SyncUtils.kAllowModification) {
      await PlaylistController.inst.importPlaylistsIfNewer(playlists);
    } else {
      snackyy(message: 'Importing ${playlists.length} playlists | ${playlists.map((e) => e.name).toFixedList()}');
    }
  }
}

class PlaylistsManifestResponseMessage extends BaseMessage {
  final List<PlaylistManifest> available;

  const PlaylistsManifestResponseMessage({
    required super.messageInfo,
    required this.available,
  }) : super(MessageType.playlistsManifestResponse);

  factory PlaylistsManifestResponseMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return PlaylistsManifestResponseMessage(
      available: PlaylistManifest.fromMapAsList(map),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => PlaylistsManifestResponseMessageUtils.encodeToMap(available);

  @override
  FutureOr<void> executeOnReceived() => PlaylistsManifestResponseMessageUtils.sendRequiredPlaylists(
    messageInfo: messageInfo,
    available: available,
    playlistsManager: PlaylistController.inst,
    createPlaylistsMessage: (playlistsToSend) => PlaylistsMessage(
      playlists: playlistsToSend,
      messageInfo: messageInfo,
    ),
  );
}
