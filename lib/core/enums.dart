// ignore_for_file: constant_identifier_names

// exporting playback enums
export 'package:basic_audio_handler/basic_audio_handler.dart' show RepeatMode, InterruptionType, InterruptionAction;

enum SortType {
  title,
  album,
  albumArtist,
  year,
  artistsList,
  genresList,
  dateAdded,
  dateModified,
  bitrate,
  composer,
  trackNo,
  discNo,
  filename,
  duration,
  sampleRate,
  size,
  rating,
  shuffle,
  mostPlayed,
  latestPlayed,
  firstListen,
}

enum GroupSortType {
  title,
  album,
  albumArtist,
  year,
  artistsList,
  genresList,
  dateModified,
  composer,
  label,
  duration,
  numberOfTracks,
  albumsCount,
  creationDate,
  modifiedDate,
  shuffle,
}

enum TrackTilePosition {
  row1Item1,
  row1Item2,
  row1Item3,
  row2Item1,
  row2Item2,
  row2Item3,
  row3Item1,
  row3Item2,
  row3Item3,
  rightItem1,
  rightItem2,
  rightItem3,
}

enum TrackTileItem {
  none,
  title,
  album,
  artists,
  albumArtist,
  genres,
  composer,
  trackNumber,
  discNumber,
  duration,
  year,
  size,
  dateAdded,
  dateModified,
  dateModifiedDate,
  dateModifiedClock,
  path,
  folder,
  fileName,
  fileNameWOExt,
  extension,
  comment,
  bitrate,
  sampleRate,
  format,
  channels,
  rating,
  tags,
  moods,
  listenCount,
  latestListenDate,
  firstListenDate,
}

enum TrackSearchFilter {
  filename,
  title,
  album,
  artist,
  albumartist,
  genre,
  composer,
  comment,
  year,
}

enum LibraryTab {
  home,
  albums,
  tracks,
  artists,
  genres,
  playlists,
  folders,
  foldersVideos,
  search,
  youtube,
}

enum TrackPlayMode {
  selectedTrack,
  searchResults,
  trackAlbum,
  trackArtist,
  trackGenre,
}

enum TrackSource {
  local,
  youtube,
  youtubeMusic,
  lastfm,
}

sealed class QueueSourceBase implements Enum {}

enum QueueSource implements QueueSourceBase {
  allTracks(false),
  album(false),
  artist(false),
  genre(false),
  playlist(true),
  folder(false),
  folderVideos(false),
  search(false),
  queuePage(true),
  playerQueue(true),
  mostPlayed(false),
  history(true),
  favourites(false),
  selectedTracks(false),
  externalFile(false),
  homePageItem(false),
  recentlyAdded(false),

  others(true);

  final bool canHaveDuplicates;
  const QueueSource(this.canHaveDuplicates);
}

enum QueueSourceYoutubeID implements QueueSourceBase {
  channel(true),
  playlist(true),
  search(false),
  playerQueue(true),
  mostPlayed(false),
  history(true),
  historyFiltered(false),
  favourites(false),
  externalLink(true),
  homeFeed(false),
  notificationsHosted(false),
  relatedVideos(false),
  historyFilteredHosted(false),
  searchHosted(false),
  channelHosted(false),
  historyHosted(true),
  playlistHosted(true),

  downloadTask(false),
  videoEndCard(false),
  videoDescription(false);

  final bool canHaveDuplicates;
  const QueueSourceYoutubeID(this.canHaveDuplicates);
}

enum TagField {
  title,
  artist,
  album,
  albumArtist,
  composer,
  genre,
  mood,
  year,
  trackNumber,
  discNumber,
  comment,
  description,
  synopsis,
  lyrics,
  remixer,
  trackTotal,
  discTotal,
  lyricist,
  language,
  recordLabel,
  country,
  rating,
  tags,
}

enum WakelockMode {
  none,
  expanded,
  expandedAndVideo,
}

enum RouteType {
  // ----- Pages -----
  PAGE_HOME,
  PAGE_allTracks,
  PAGE_albums,
  PAGE_artists,
  PAGE_genres,
  PAGE_playlists,
  PAGE_folders,
  PAGE_folders_videos,
  PAGE_queue,
  PAGE_stats,
  PAGE_about,

  // ----- Subpages -----
  SUBPAGE_recentlyAddedTracks,
  SUBPAGE_albumTracks,
  SUBPAGE_artistTracks,
  SUBPAGE_albumArtistTracks,
  SUBPAGE_composerTracks,
  SUBPAGE_genreTracks,
  SUBPAGE_playlistTracks,
  SUBPAGE_historyTracks,
  SUBPAGE_mostPlayedTracks,
  SUBPAGE_queueTracks,
  SUBPAGE_INDEXER_UPDATE_MISSING_TRACKS,

  // ----- Subpages -----
  SETTINGS_page,
  SETTINGS_subpage,

  // ----- Search Results -----
  SEARCH_albumResults,
  SEARCH_artistResults,

  // ----- Youtube -----
  YOUTUBE_HOME,
  YOUTUBE_PLAYLISTS,
  YOUTUBE_PLAYLIST_SUBPAGE,
  YOUTUBE_PLAYLIST_DOWNLOAD_SUBPAGE,
  YOUTUBE_PLAYLIST_SUBPAGE_HOSTED,
  YOUTUBE_LIKED_SUBPAGE,
  YOUTUBE_HISTORY_SUBPAGE,
  YOUTUBE_MOST_PLAYED_SUBPAGE,
  YOUTUBE_CHANNEL_SUBPAGE,

  YOUTUBE_USER_MANAGE_ACCOUNT_SUBPAGE,
  YOUTUBE_USER_MANAGE_SUBSCRIPTION_SUBPAGE,

  YOUTUBE_HISTORY_HOSTED_SUBPAGE,

  /// others
  UNKNOWN,
}

/// Used for search and sort.
enum MediaType {
  track,
  album,
  artist,
  albumArtist,
  composer,
  genre,
  playlist,

  /// not used
  folder,
  folderVideo,
}

enum VideoPlaybackSource {
  auto,
  local,
  youtube,
}

enum LyricsSource {
  auto,
  local,
  internet,
}

enum QueueInsertionType {
  moreAlbum,
  moreArtist,
  moreFolder,
  random,
  listenTimeRange,
  mood,
  rating,
  sameReleaseDate,
  algorithm,
  mix,
}

enum InsertionSortingType {
  /// random sort
  random,

  /// total listen count
  listenCount,

  /// sort by user rating
  rating,

  /// default implementation. can be slected listens count or no sorting.
  none,
}

enum LocalVideoMatchingType {
  auto,
  filename,
  titleAndArtist,
}

enum HomePageItems {
  mixes,
  recentListens,
  topRecentListens,
  lostMemories,
  recentlyAdded,
  recentAlbums,
  recentArtists,
  topRecentAlbums,
  topRecentArtists,
}

enum MixesItems {
  topRecents,
  supremacy,
  favourites,
  randomPicks,
}

enum NotificationTapAction {
  openApp,
  openMiniplayer,
  openQueue,
}

enum SearchType {
  localTracks,
  youtube,
  localVideos,
}

enum AlbumIdentifier {
  albumName,
  year,
  albumArtist,
}

enum OnYoutubeLinkOpenAction {
  showDownload,
  play,
  playNext,
  playAfter,
  playLast,
  addToPlaylist,
  alwaysAsk,
}

enum PerformanceMode {
  highPerformance,
  balanced,
  goodLooking,
  custom,
}

enum KillAppMode {
  always,
  ifNotPlaying,
  never,
}

enum SettingSubpageEnum {
  theme,
  indexer,
  playback,
  customization,
  youtube,
  extra,
  backupRestore,
  advanced,
}

enum FABType {
  none,
  play,
  shuffle,
  search,
}

enum YTHomePages {
  home,
  notifications,
  channels,
  playlists,
  userplaylists,
  downloads,
}

enum SetMusicAsAction {
  ringtone,
  notification,
  alarm,
}

enum YTSeekActionMode {
  none,
  minimizedMiniplayer,
  expandedMiniplayer,
  all,
}

enum YTVisibleShortPlaces {
  homeFeed,
  search,
  history,
  relatedVideos,
}

enum YTVisibleMixesPlaces {
  homeFeed,
  search,
  relatedVideos,
}

enum OnTrackTileSwapActions {
  none,
  playnext,
  playlast,
  playafter,
  addtoplaylist,
}

enum CacheVideoPriority {
  VIP,
  high,
  normal,
  low,
  GETOUT,
}

enum YTSortType {
  title,
  channelTitle,
  duration,
  date,
  dateAdded,
  shuffle,
  mostPlayed,
  latestPlayed,
  firstListen,
}

enum DownloadNotifications {
  disableAll,
  showAll,
  showFailedOnly,
}

enum DataSaverMode {
  off,
  medium,
  extreme;

  bool get canFetchNetworkVideoStream => this == DataSaverMode.off;
}
