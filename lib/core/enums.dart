// ignore_for_file: constant_identifier_names

import 'package:namida/controller/platform/base.dart';
import 'package:namida/core/constants.dart';

export 'package:basic_audio_handler/basic_audio_handler.dart' show RepeatMode, InterruptionType, InterruptionAction;
export 'package:history_manager/history_manager.dart' show TrackSource;

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
  firstListen;

  bool get requiresHistory => this == SortType.mostPlayed || this == SortType.latestPlayed || this == SortType.firstListen;
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
  playCount,
  latestPlayed,
  firstListen,
  albumsCount,
  creationDate,
  modifiedDate,
  shuffle;

  bool get requiresHistory => this == GroupSortType.playCount || this == GroupSortType.latestPlayed || this == GroupSortType.firstListen;
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
  folder,
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

sealed class QueueSourceBase implements Enum {}

enum QueueSource implements QueueSourceBase {
  allTracks(false),
  album(false),
  artist(false),
  albumArtist(false),
  composer(false),
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
  SUBPAGE_favPlaylistTracks,
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
  algorithmDiscoverDate,
  algorithmTimeRange,
  mix;

  int? get recommendedSampleCount => switch (this) {
        QueueInsertionType.algorithm => 10,
        QueueInsertionType.algorithmDiscoverDate => 2,
        QueueInsertionType.algorithmTimeRange => null,
        _ => null,
      };

  int? get recommendedSampleDaysCount => switch (this) {
        QueueInsertionType.algorithm => null,
        QueueInsertionType.algorithmDiscoverDate => 28,
        QueueInsertionType.algorithmTimeRange => 7,
        _ => null,
      };
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
  youtubeID,
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
  openinfo,
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
  bool canFetchNetworkVideoStreamShortContent(bool? isShortContent) {
    if (isShortContent == true) {
      return this == DataSaverMode.off || this == DataSaverMode.medium;
    }
    return this == DataSaverMode.off;
  }
}

enum InternalPlayerType {
  auto,
  exoplayer,
  exoplayer_sw,
  mpv;

  InternalPlayerType ensureResolved() {
    var instance = this;
    if (instance == InternalPlayerType.auto) {
      instance = InternalPlayerType.platformDefault;
    }
    return instance;
  }

  bool get shouldInitializeMPV => ensureResolved() == InternalPlayerType.mpv;

  static List<InternalPlayerType> getAvailableForCurrentPlatform() {
    final nativePlayers = NamidaPlatformBuilder.init(
      android: () => const [InternalPlayerType.exoplayer, InternalPlayerType.exoplayer_sw],
      ios: () => const [InternalPlayerType.exoplayer],
      windows: () => const [InternalPlayerType.mpv],
      macos: () => const [InternalPlayerType.mpv],
      linux: () => const [InternalPlayerType.mpv],
    );
    return [
      InternalPlayerType.auto,
      ...nativePlayers,
    ];
  }

  static final InternalPlayerType platformDefault = InternalPlayerType._getForPlatform();

  factory InternalPlayerType._getForPlatform() {
    return NamidaPlatformBuilder.init(
      android: () => InternalPlayerType.exoplayer,
      ios: () => InternalPlayerType.exoplayer,
      windows: () => InternalPlayerType.mpv,
      macos: () => InternalPlayerType.mpv,
      linux: () => InternalPlayerType.mpv,
    );
  }

  String getInfoForAndroid() {
    return switch (this) {
      InternalPlayerType.auto => InternalPlayerType.platformDefault.name,
      InternalPlayerType.exoplayer =>
        "HW Decoder. Good with most formats, can fallback to sw decoder if it can't play something, but sometimes won't. Always Recommended Unless you have playback issues.",
      InternalPlayerType.exoplayer_sw => "SW Decoder. Can play almost all formats like mpv, only issue is high cpu/battery usage due to it being a software decoder.",
      InternalPlayerType.mpv =>
        """HW Decoder. Can play almost all formats like ffmpeg, but with normal cpu/battery. It's used mainly for pc version so it lacks some features for android like: 
skip silence, looping animations, gapless, equalizer & equalizer presets, loudness enhancer,
quick settings tile, picture in picture
""",
    };
  }
}

enum VibrationType {
  none,
  vibration,
  haptic_feedback,
}

enum ReplayGainType {
  off(false),
  platform_default(false),
  loudness_enhancer(true),
  volume(true);

  final bool _isValidMode;
  const ReplayGainType(this._isValidMode);

  static ReplayGainType getPlatformDefault() => NamidaFeaturesVisibility.loudnessEnhancerAvailable ? loudness_enhancer : volume;

  bool get isLoudnessEnhancerEnabled => this == loudness_enhancer || (this == platform_default && getPlatformDefault() == loudness_enhancer);
  bool get isVolumeEnabled => this == volume || (this == platform_default && getPlatformDefault() == volume);

  bool get isAnyEnabled => this != off;

  static List<ReplayGainType> get valuesForPlatform {
    var newList = List<ReplayGainType>.from(ReplayGainType.values);
    if (!NamidaFeaturesVisibility.loudnessEnhancerAvailable) newList.remove(ReplayGainType.loudness_enhancer);
    if (newList.where((element) => element._isValidMode).length <= 1) {
      newList.remove(ReplayGainType.platform_default);
    }
    return newList;
  }
}

enum LibraryImageSource {
  local,
  lastfm;

  bool get isNetwork => this == lastfm;
}

enum AlbumType {
  single,
  normal;
}
