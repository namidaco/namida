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
      return YoutubeHistoryController.inst.addTracksToHistoryImportPreventDuplicates(videos);
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

class YTSubscriptionsMessage extends BaseMessage {
  final Iterable<YoutubeSubscription> channels;

  const YTSubscriptionsMessage({
    required this.channels,
    required super.messageInfo,
  }) : super(MessageType.ytSubscriptions);

  static Future<YTSubscriptionsMessage> createForCurrentDevice() async {
    return YTSubscriptionsMessage(
      channels: YoutubeSubscriptionsController.inst.buildSyncEntries(),
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
  }

  static YoutubeSubscription? _tryParse(dynamic map) {
    try {
      return YoutubeSubscription.fromJson((map as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  factory YTSubscriptionsMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return YTSubscriptionsMessage(
      channels: (map['c'] as List).map(_tryParse).nonNulls,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'c': channels.map((e) => e.toJson()).toFixedList(),
  };

  @override
  String toRawInfo() => 'YTSubscriptions(${channels.length} channels)';

  @override
  FutureOr<void> executeOnReceived() {
    if (SyncUtils.kAllowModification) {
      return YoutubeSubscriptionsController.inst.import(channels);
    } else {
      snackyy(message: 'Importing ${channels.length} yt subscriptions');
    }
  }
}

class YTSubscriptionsGroupsMessage extends BaseMessage {
  final List<String> groups;

  const YTSubscriptionsGroupsMessage({
    required this.groups,
    required super.messageInfo,
  }) : super(MessageType.ytSubscriptionsGroups);

  static Future<YTSubscriptionsGroupsMessage> createForCurrentDevice() async {
    return YTSubscriptionsGroupsMessage(
      groups: await YoutubeSubscriptionsController.inst.readAllGroups(),
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
  }

  factory YTSubscriptionsGroupsMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return YTSubscriptionsGroupsMessage(
      groups: (map['g'] as List).cast<String>(),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'g': groups,
  };

  @override
  FutureOr<void> executeOnReceived() {
    if (SyncUtils.kAllowModification) {
      return YoutubeSubscriptionsController.inst.importGroups(groups);
    } else {
      snackyy(message: 'Importing ${groups.length} yt subscription groups');
    }
  }
}

class YTLikesMessage extends BaseMessage {
  final Iterable<YoutubeID> videos;

  const YTLikesMessage({
    required this.videos,
    required super.messageInfo,
  }) : super(MessageType.ytLikes);

  factory YTLikesMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return YTLikesMessage(
      videos: (map['videos'] as List).map((e) => YoutubeID.fromJson(e)),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'videos': videos.map((e) => e.toJson()).toFixedList(),
  };

  @override
  String toRawInfo() => 'YTLikes(${videos.length} videos)';

  @override
  FutureOr<void> executeOnReceived() async {
    if (SyncUtils.kAllowModification) {
      final favouritesPlaylist = YoutubePlaylistController.inst.favouritesPlaylist.value;
      // -- adds only missing videos, keeping their original date added
      await YoutubePlaylistController.inst.importTracksToPlaylist(
        favouritesPlaylist,
        videos.map(
          (e) => YoutubeID(
            id: e.id,
            watchNull: e.watchNull,
            playlistID: favouritesPlaylist.playlistID,
          ),
        ),
      );
    } else {
      snackyy(message: 'Importing ${videos.length} yt likes | ${videos.take(10).map((e) => e.id).toFixedList()}');
    }
  }
}

class YTPlaylistsManifestResponseMessage extends BaseMessage {
  final List<PlaylistManifest> available;
  final SyncBatchRef? batchRef;

  const YTPlaylistsManifestResponseMessage({
    required super.messageInfo,
    required this.available,
    required this.batchRef,
  }) : super(MessageType.ytPlaylistsManifestResponse);

  factory YTPlaylistsManifestResponseMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return YTPlaylistsManifestResponseMessage(
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
    playlistsManager: YoutubePlaylistController.inst,
    tracksArePaths: false,
    batchRef: batchRef,
    createPlaylistsMessage: (playlistsToSend, createdMessageInfo) => YTPlaylistsMessage(
      playlists: playlistsToSend,
      messageInfo: createdMessageInfo,
    ),
  );
}
