part of '../sync_manager.dart';

class YTHistoryListensMessage extends BaseMessage {
  final Iterable<YoutubeID> videos;

  const YTHistoryListensMessage({
    required this.videos,
    required super.messageInfo,
  }) : super(MessageType.ytHistoryListens);

  factory YTHistoryListensMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return YTHistoryListensMessage(
      videos: (map['videos'] as List).map((e) => YoutubeID.fromJson(e)),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'videos': videos.map((e) => e.toJson()).toFixedList(),
  };

  @override
  FutureOr<void> executeOnReceived() {
    if (SyncUtils.kAllowModification) {
      return YoutubeHistoryController.inst.addTracksToHistory(videos);
    } else {
      snackyy(message: 'Importing ${videos.length} yt listen | ${videos.take(10).map((e) => e.id).toFixedList()}');
    }
  }
}

class YTPlaylistsMessage extends BaseMessage {
  final Iterable<YoutubePlaylist> playlists;

  const YTPlaylistsMessage({
    required this.playlists,
    required super.messageInfo,
  }) : super(MessageType.ytPlaylists);

  factory YTPlaylistsMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return YTPlaylistsMessage(
      playlists: (map['playlists'] as List).map((e) => YoutubePlaylist.fromJson(e, YoutubeID.fromJson, YTSortType.sortListFromJsonList)),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'playlists': playlists.map((e) => e.toJson((item) => item.toJson(), YTSortType.sortsToJson)).toFixedList(),
  };

  @override
  FutureOr<void> executeOnReceived() async {
    if (SyncUtils.kAllowModification) {
      await YoutubePlaylistController.inst.importPlaylistsIfNewer(playlists);
    } else {
      snackyy(message: 'Importing ${playlists.length} yt playlists | ${playlists.map((e) => e.name).toFixedList()}');
    }
  }
}

class YTPlaylistsManifestResponseMessage extends BaseMessage {
  final List<PlaylistManifest> available;

  const YTPlaylistsManifestResponseMessage({
    required super.messageInfo,
    required this.available,
  }) : super(MessageType.ytPlaylistsManifestResponse);

  factory YTPlaylistsManifestResponseMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return YTPlaylistsManifestResponseMessage(
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
    playlistsManager: YoutubePlaylistController.inst,
    createPlaylistsMessage: (playlistsToSend) => YTPlaylistsMessage(
      playlists: playlistsToSend,
      messageInfo: messageInfo,
    ),
  );
}
