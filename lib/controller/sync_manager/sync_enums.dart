part of 'sync_manager.dart';

enum MessageType {
  ping(isDataTransfer: false, carriesSenderPaths: false),
  connectionRequest(isDataTransfer: false, carriesSenderPaths: false),
  messageRequest(isDataTransfer: false, carriesSenderPaths: false),
  syncItemsRequest(isDataTransfer: false, carriesSenderPaths: false),
  historyListens(isDataTransfer: true, carriesSenderPaths: true),
  playlists(isDataTransfer: true, carriesSenderPaths: true),
  tracksDbFingerprints(isDataTransfer: true, carriesSenderPaths: false),
  latestPlayedForSource(isDataTransfer: true, carriesSenderPaths: true),
  audioConfigs(isDataTransfer: true, carriesSenderPaths: true),
  smartPlaylists(isDataTransfer: true, carriesSenderPaths: false),
  trackStats(isDataTransfer: true, carriesSenderPaths: true),
  favourites(isDataTransfer: true, carriesSenderPaths: true),
  ytHistoryListens(isDataTransfer: true, carriesSenderPaths: false),
  ytPlaylists(isDataTransfer: true, carriesSenderPaths: false),
  ytLikes(isDataTransfer: true, carriesSenderPaths: false),
  ytSubscriptions(isDataTransfer: true, carriesSenderPaths: false),
  ytSubscriptionsGroups(isDataTransfer: true, carriesSenderPaths: false),

  playlistsManifestResponse(isDataTransfer: false, carriesSenderPaths: false),
  ytPlaylistsManifestResponse(isDataTransfer: false, carriesSenderPaths: false),

  dirFilesManifestRequest(isDataTransfer: false, carriesSenderPaths: false),
  dirFilesManifestResponse(isDataTransfer: false, carriesSenderPaths: false),
  dirFile(isDataTransfer: true, carriesSenderPaths: false),
  dbFile(isDataTransfer: true, carriesSenderPaths: false),
  dbManifestRequest(isDataTransfer: false, carriesSenderPaths: false),
  dbManifestResponse(isDataTransfer: false, carriesSenderPaths: false),
  dbEntries(isDataTransfer: true, carriesSenderPaths: false),

  playerQueue(isDataTransfer: true, carriesSenderPaths: true),
  playback(isDataTransfer: true, carriesSenderPaths: false),
  ;

  /// wether this message carries actual data (not pings/connection/manifest/etc).
  /// used in [SyncActionsLog].
  final bool isDataTransfer;

  final bool carriesSenderPaths;

  const MessageType({required this.isDataTransfer, required this.carriesSenderPaths});

  static final lookupMap = values.asNameMap();
}

enum MessageActionType {
  add,
  edit,
  delete,
  connection,
  manifest,
  ;

  static final lookupMap = values.asNameMap();
}

enum MessageRequestType {
  playlistsManifest,
  ytPlaylistsManifest,
  playerQueue,
  tracksDbFingerprints,
  ;

  static final lookupMap = values.asNameMap();
}

enum ConnectionRequestMessageType {
  /// client -> server
  connect,

  /// client -> server
  disconnect,

  // -----------------

  /// server -> client
  accepted,

  /// server -> client
  rejected,

  /// server -> client
  blocked,

  /// server -> client
  unblocked,
}
