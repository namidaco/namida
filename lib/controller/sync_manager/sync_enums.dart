part of 'sync_manager.dart';

enum MessageType {
  ping,
  connectionRequest,
  messageRequest,
  historyListens,
  playlists,
  ytHistoryListens,
  ytPlaylists,

  playlistsManifestResponse,
  ytPlaylistsManifestResponse,
  ;

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
