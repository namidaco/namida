// ignore_for_file: public_member_api_docs, sort_constructors_first
// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:modern_titlebar_buttons/modern_titlebar_buttons.dart' as mtb;

import 'package:namida/class/queue.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

export 'package:basic_audio_handler/basic_audio_handler.dart' show PlayerRepeatMode, InterruptionType, InterruptionAction;
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
  path,
  duration,
  sampleRate,
  size,
  rating,
  shuffle,
  mostPlayed,
  latestPlayed,
  firstListen,
  titleSort,
  albumSort,
  albumArtistSort,
  artistSort,
  composerSort,
  ;

  bool get requiresHistory => this == SortType.mostPlayed || this == SortType.latestPlayed || this == SortType.firstListen;

  static List<SortType> forTracks() => [
    SortType.title,
    SortType.album,
    SortType.artistsList,
    SortType.albumArtist,
    SortType.composer,
    SortType.genresList,
    SortType.year,
    SortType.dateAdded,
    SortType.dateModified,
    SortType.bitrate,
    SortType.trackNo,
    SortType.discNo,
    SortType.filename,
    SortType.path,
    SortType.duration,
    SortType.sampleRate,
    SortType.size,
    SortType.rating,
    SortType.latestPlayed,
    SortType.mostPlayed,
    SortType.firstListen,
    SortType.titleSort,
    SortType.albumSort,
    SortType.albumArtistSort,
    SortType.artistSort,
    SortType.composerSort,
    SortType.shuffle,
  ];
}

enum GroupSortType {
  title,
  album,
  albumArtist,
  year,
  artistsList,
  genresList,
  dateAdded,
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
  albumSort,
  albumArtistSort,
  artistSort,
  composerSort,
  shuffle,
  custom,
  ;

  bool get requiresHistory => this == GroupSortType.playCount || this == GroupSortType.latestPlayed || this == GroupSortType.firstListen;

  static List<GroupSortType> forAlbums() => [
    GroupSortType.album,
    GroupSortType.albumSort,
    GroupSortType.albumArtist,
    GroupSortType.year,
    GroupSortType.duration,
    GroupSortType.numberOfTracks,
    GroupSortType.playCount,
    GroupSortType.firstListen,
    GroupSortType.latestPlayed,
    GroupSortType.dateAdded,
    GroupSortType.dateModified,
    GroupSortType.artistsList,
    GroupSortType.composer,
    GroupSortType.label,
    GroupSortType.shuffle,
  ];

  static List<GroupSortType> forArtists(MediaType artistType) => [
    artistType == MediaType.albumArtist
        ? GroupSortType.albumArtist
        : artistType == MediaType.composer
        ? GroupSortType.composer
        : GroupSortType.artistsList,
    artistType == MediaType.albumArtist
        ? GroupSortType.albumArtistSort
        : artistType == MediaType.composer
        ? GroupSortType.composerSort
        : GroupSortType.artistSort,
    GroupSortType.duration,
    GroupSortType.numberOfTracks,
    GroupSortType.albumsCount,
    GroupSortType.playCount,
    GroupSortType.firstListen,
    GroupSortType.latestPlayed,
    GroupSortType.genresList,
    GroupSortType.album,
    GroupSortType.year,
    GroupSortType.dateAdded,
    GroupSortType.dateModified,
    GroupSortType.shuffle,
  ];

  static List<GroupSortType> forGenres() => [
    GroupSortType.genresList,
    GroupSortType.duration,
    GroupSortType.numberOfTracks,
    GroupSortType.playCount,
    GroupSortType.firstListen,
    GroupSortType.latestPlayed,
    GroupSortType.year,
    GroupSortType.artistsList,
    GroupSortType.album,
    GroupSortType.albumArtist,
    GroupSortType.dateAdded,
    GroupSortType.dateModified,
    GroupSortType.composer,
    GroupSortType.shuffle,
  ];

  static List<GroupSortType> forPlaylists() => [
    GroupSortType.title,
    GroupSortType.creationDate,
    GroupSortType.modifiedDate,
    GroupSortType.duration,
    GroupSortType.numberOfTracks,
    GroupSortType.playCount,
    GroupSortType.firstListen,
    GroupSortType.latestPlayed,
    GroupSortType.shuffle,
    GroupSortType.custom,
  ];

  static Iterable<GroupSortType> forYTPlaylists() => [
    GroupSortType.title,
    GroupSortType.creationDate,
    GroupSortType.modifiedDate,
    GroupSortType.numberOfTracks,
    GroupSortType.playCount,
    GroupSortType.firstListen,
    GroupSortType.latestPlayed,
    GroupSortType.shuffle,
    GroupSortType.custom,
  ];
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
  lyrics,
}

enum LibraryTab {
  home,
  albums,
  tracks,
  artists,
  genres,
  playlists,
  folders,
  foldersMusic,
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

enum QueueSourceEnum {
  allTracks(false, supportResuming: true),
  album(false, supportResuming: true),
  artist(false, supportResuming: true),
  albumArtist(false, supportResuming: true),
  composer(false, supportResuming: true),
  genre(false, supportResuming: true),
  playlist(true, supportResuming: true),
  folder(false),
  folderMusic(false),
  folderVideos(false),
  search(false),
  queuePage(true, supportResuming: true),
  playerQueue(true),
  mostPlayed(false),
  history(true),
  favourites(false, supportResuming: true),
  selectedTracks(false),
  externalFile(false),
  homePageItem(false),
  recentlyAdded(false),

  others(true)
  ;

  final bool canHaveDuplicates;
  final bool supportResuming;
  const QueueSourceEnum(this.canHaveDuplicates, {this.supportResuming = false});
}

enum QueueSourceYoutubeIDEnum {
  // -- must have different name from QueueSourceEnum
  // -- so that name matching works properly

  ytChannel(true),
  ytPlaylist(true, supportResuming: true),
  ytSearch(false),
  ytPlayerQueue(true),
  ytMostPlayed(false),
  ytHistory(true),
  ytHistoryFiltered(false),
  ytFavourites(false, supportResuming: true),
  ytExternalLink(true),
  ytHomeFeed(false),
  ytNotificationsHosted(false),
  ytRelatedVideos(false),
  ytHistoryFilteredHosted(false),
  ytSearchHosted(false),
  ytChannelHosted(false),
  ytHistoryHosted(true),
  ytPlaylistHosted(true),

  ytDownloadTask(false),
  ytVideoEndCard(false),
  ytVideoDescription(false)
  ;

  final bool canHaveDuplicates;
  final bool supportResuming;
  const QueueSourceYoutubeIDEnum(this.canHaveDuplicates, {this.supportResuming = false});
}

sealed class QueueSourceBase<E extends Enum> {
  final E s;
  bool get canHaveDuplicates;
  bool get supportResuming;

  final String? title;
  const QueueSourceBase._(this.s, {required this.title});

  dynamic toJson();
  String toDbKey() => jsonEncode(toJson());
}

class QueueSource extends QueueSourceBase<QueueSourceEnum> {
  @override
  bool get canHaveDuplicates => s.canHaveDuplicates;
  @override
  bool get supportResuming => s.supportResuming;

  const QueueSource._(super.s, {super.title}) : super._();

  static const allTracks = QueueSource._(QueueSourceEnum.allTracks);
  static QueueSource album(String? name) => QueueSource._(QueueSourceEnum.album, title: name);
  static QueueSource artist(String? name) => QueueSource._(QueueSourceEnum.artist, title: name);
  static QueueSource albumArtist(String? name) => QueueSource._(QueueSourceEnum.albumArtist, title: name);
  static QueueSource composer(String? name) => QueueSource._(QueueSourceEnum.composer, title: name);
  static QueueSource genre(String? name) => QueueSource._(QueueSourceEnum.genre, title: name);
  static QueueSource playlist(String? name) => QueueSource._(QueueSourceEnum.playlist, title: name);
  static QueueSource folder(String? name) => QueueSource._(QueueSourceEnum.folder, title: name);
  static QueueSource folderMusic(String? name) => QueueSource._(QueueSourceEnum.folderMusic, title: name);
  static QueueSource folderVideos(String? name) => QueueSource._(QueueSourceEnum.folderVideos, title: name);
  static const search = QueueSource._(QueueSourceEnum.search, title: null);
  static QueueSource queuePage(Queue? queue) => queuePageByName(queue?.getKey());
  static QueueSource queuePageByName(String? name) => QueueSource._(QueueSourceEnum.queuePage, title: name);
  static const playerQueue = QueueSource._(QueueSourceEnum.playerQueue);
  static const mostPlayed = QueueSource._(QueueSourceEnum.mostPlayed);
  static const history = QueueSource._(QueueSourceEnum.history);
  static const favourites = QueueSource._(QueueSourceEnum.favourites);
  static const selectedTracks = QueueSource._(QueueSourceEnum.selectedTracks);
  static const externalFile = QueueSource._(QueueSourceEnum.externalFile);
  static const homePageItem = QueueSource._(QueueSourceEnum.homePageItem);
  static const recentlyAdded = QueueSource._(QueueSourceEnum.recentlyAdded);

  static QueueSource others(String? name) => QueueSource._(QueueSourceEnum.others, title: name);

  static QueueSource? fromJson(dynamic value) {
    String? sourceString;
    String? title;
    if (value is Map) {
      sourceString = value['s'];
      title = value['t'];
    } else if (value is String) {
      sourceString = value;
    }

    if (sourceString != null) {
      final v = QueueSourceEnum.values.getEnum(sourceString);
      if (v != null) {
        return QueueSource._(v, title: title);
      }
    }

    return null;
  }

  @override
  dynamic toJson() {
    if (title == null) {
      return s.name;
    }
    return {
      't': title,
      's': s.name,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueueSource && other.s == s && other.title == title;
  }

  @override
  int get hashCode => s.hashCode ^ title.hashCode;

  @override
  String toString() => 'QueueSource(s: $s, title: $title)';
}

class QueueSourceYoutubeID extends QueueSourceBase<QueueSourceYoutubeIDEnum> {
  @override
  bool get canHaveDuplicates => s.canHaveDuplicates;
  @override
  bool get supportResuming => s.supportResuming;

  const QueueSourceYoutubeID._(super.s, {super.title}) : super._();

  static QueueSourceYoutubeID ytChannel(String? name) => QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytChannel, title: name);
  static QueueSourceYoutubeID ytPlaylist(String? name) => QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytPlaylist, title: name);
  static const ytSearch = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytSearch);
  static const ytPlayerQueue = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytPlayerQueue);
  static const ytMostPlayed = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytMostPlayed);
  static const ytHistory = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytHistory);
  static const ytHistoryFiltered = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytHistoryFiltered);
  static const ytFavourites = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytFavourites);
  static const ytExternalLink = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytExternalLink);
  static const ytHomeFeed = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytHomeFeed);
  static const ytNotificationsHosted = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytNotificationsHosted);
  static const ytRelatedVideos = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytRelatedVideos);
  static const ytHistoryFilteredHosted = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytHistoryFilteredHosted);
  static const ytSearchHosted = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytSearchHosted);
  static const ytChannelHosted = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytChannelHosted);
  static const ytHistoryHosted = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytHistoryHosted);
  static const ytPlaylistHosted = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytPlaylistHosted);

  static const ytDownloadTask = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytDownloadTask);
  static const ytVideoEndCard = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytVideoEndCard);
  static const ytVideoDescription = QueueSourceYoutubeID._(QueueSourceYoutubeIDEnum.ytVideoDescription);

  static QueueSourceYoutubeID? fromJson(dynamic value) {
    String? sourceString;
    String? title;
    if (value is Map) {
      sourceString = value['s'];
      title = value['t'];
    } else if (value is String) {
      sourceString = value;
    }

    if (sourceString != null) {
      final v = QueueSourceYoutubeIDEnum.values.getEnum(sourceString);
      if (v != null) {
        return QueueSourceYoutubeID._(v, title: title);
      }
    }

    return null;
  }

  @override
  dynamic toJson() {
    if (title == null) {
      return s.name;
    }
    return {
      't': title,
      's': s.name,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueueSourceYoutubeID && other.s == s && other.title == title;
  }

  @override
  int get hashCode => s.hashCode ^ title.hashCode;

  @override
  String toString() => 'QueueSourceYoutubeID(s: $s, title: $title)';
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

  titleSort,
  albumSort,
  albumArtistSort,
  artistSort,
  composerSort,
}

enum WakelockMode {
  none,
  expanded,
  expandedAndVideo,
}

enum RouteType {
  // ----- Pages -----
  PAGE_Home,
  PAGE_allTracks,
  PAGE_albums,
  PAGE_artists,
  PAGE_genres,
  PAGE_playlists,
  PAGE_folders,
  PAGE_folders_music,
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
  YOUTUBE_USER_CHANNELS_PAGE_HOSTED,

  YOUTUBE_USER_MANAGE_ACCOUNT_SUBPAGE,
  YOUTUBE_USER_MANAGE_SUBSCRIPTION_SUBPAGE,
  YOUTUBE_SPONSORBLOCK_SUBPAGE,
  YOUTUBE_RETURN_YOUTUBE_DISLIKE_SUBPAGE,

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
  folderMusic,
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
  mix
  ;

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
  auto, // must be at the end, indices are used
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

enum TrackExecuteActions {
  none,
  playnext,
  playlast,
  playafter,
  addtoplaylist,
  openinfo,

  openArtwork,
  editArtwork,
  saveArtwork,
  editTags,
  setRating,
  openListens,
  goToAlbum,
  goToArtist,
  goToFolder,
  copyTitle,
  copyArtist,
  copyArtistAndTitle,
  copyYTLink,
  searchYTSimilar,
  delete,
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
  extreme
  ;

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
  mpv
  ;

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
  volume(true)
  ;

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
  lastfm
  ;

  bool get isNetwork => this == lastfm;
}

enum AlbumType {
  single,
  normal,
}

enum TrackTypeSearch {
  tr,
  v,
}

enum DesktopTitlebarIconsType {
  none,
  auto,
  adwaita,
  arc,
  breeze,
  elementary,
  flatRemix,
  materia,
  nordic,
  osxArc,
  pop,
  unity,
  vimix,
  yaru,
  ;

  mtb.ThemeType? toThemeType() {
    return switch (this) {
      DesktopTitlebarIconsType.none => null,
      DesktopTitlebarIconsType.auto => mtb.ThemeType.auto,
      DesktopTitlebarIconsType.adwaita => mtb.ThemeType.adwaita,
      DesktopTitlebarIconsType.arc => mtb.ThemeType.arc,
      DesktopTitlebarIconsType.breeze => mtb.ThemeType.breeze,
      DesktopTitlebarIconsType.elementary => mtb.ThemeType.elementary,
      DesktopTitlebarIconsType.flatRemix => mtb.ThemeType.flatRemix,
      DesktopTitlebarIconsType.materia => mtb.ThemeType.materia,
      DesktopTitlebarIconsType.nordic => mtb.ThemeType.nordic,
      DesktopTitlebarIconsType.osxArc => mtb.ThemeType.osxArc,
      DesktopTitlebarIconsType.pop => mtb.ThemeType.pop,
      DesktopTitlebarIconsType.unity => mtb.ThemeType.unity,
      DesktopTitlebarIconsType.vimix => mtb.ThemeType.vimix,
      DesktopTitlebarIconsType.yaru => mtb.ThemeType.yaru,
    };
  }
}
