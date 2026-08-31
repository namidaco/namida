part of 'sync_manager.dart';

enum MessageType {
  ping(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  connectionRequest(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  messageRequest(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: true),
  batchInfo(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  syncItemsRequest(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  historyListens(isDataTransfer: true, carriesSenderPaths: true, isManifestResponse: false, isManifestRequest: false),
  playlists(isDataTransfer: true, carriesSenderPaths: true, isManifestResponse: false, isManifestRequest: false),
  tracksDbFingerprints(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  latestPlayedForSource(isDataTransfer: true, carriesSenderPaths: true, isManifestResponse: false, isManifestRequest: false),
  audioConfigs(isDataTransfer: true, carriesSenderPaths: true, isManifestResponse: false, isManifestRequest: false),
  smartPlaylists(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  trackStats(isDataTransfer: true, carriesSenderPaths: true, isManifestResponse: false, isManifestRequest: false),
  favourites(isDataTransfer: true, carriesSenderPaths: true, isManifestResponse: false, isManifestRequest: false),
  ytHistoryListens(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  ytPlaylists(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  ytLikes(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  ytSubscriptions(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  ytSubscriptionsGroups(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),

  playlistsManifestResponse(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: true, isManifestRequest: false),
  ytPlaylistsManifestResponse(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: true, isManifestRequest: false),

  dirFilesManifestRequest(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: true),
  dirFilesManifestResponse(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: true, isManifestRequest: false),
  dirFile(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  dbFile(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  dbManifestRequest(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: true),
  dbManifestResponse(isDataTransfer: false, carriesSenderPaths: false, isManifestResponse: true, isManifestRequest: false),
  dbEntries(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),

  playerQueue(isDataTransfer: true, carriesSenderPaths: true, isManifestResponse: false, isManifestRequest: false),
  playback(isDataTransfer: true, carriesSenderPaths: false, isManifestResponse: false, isManifestRequest: false),
  ;

  /// wether this message carries actual data (not pings/connection/manifest/etc).
  /// used in [SyncActionsLog].
  final bool isDataTransfer;

  final bool carriesSenderPaths;

  /// wether this type is a manifest response.
  /// can be used to regulate order to avoid sending multiple data types at the same time
  final bool isManifestResponse;

  /// wether this type only asks for a manifest, meaning the actual data transfer
  /// happens later when the response lands back on us. see [SyncBatch].
  final bool isManifestRequest;

  const MessageType({
    required this.isDataTransfer,
    required this.carriesSenderPaths,
    required this.isManifestResponse,
    required this.isManifestRequest,
  });

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
