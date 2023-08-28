// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:collection';

import 'package:flutter/services.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';

///
int kSdkVersion = 21;

final Set<String> kStoragePaths = {};
final Set<String> kDirectoriesPaths = {};
final List<double> kDefaultWaveFormData = List<double>.filled(1, 2.0);
final List<double> kDefaultScaleList = List<double>.filled(1, 0.01);
final RegExp kYoutubeRegex = RegExp(
  r'\b(?:https?://)?(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)([\w\-]+)(?:\S+)?',
  caseSensitive: false,
);
const String k_NAMIDA_SUPPORT_LINK = '';

/// Main Color
const Color kMainColor = Color.fromARGB(160, 117, 128, 224);
const Color kMainColorLight = Color.fromARGB(255, 116, 126, 219);
const Color kMainColorDark = Color.fromARGB(255, 139, 149, 241);

/// Files used by Namida
class AppPaths {
  static final _USER_DATA = AppDirs.USER_DATA;

  static final SETTINGS = '$_USER_DATA/namida_settings.json';
  static final TRACKS = '$_USER_DATA/tracks.json';
  static final VIDEOS_LOCAL = '$_USER_DATA/local_videos.json';
  static final VIDEOS_CACHE = '$_USER_DATA/cache_videos.json';
  static final TRACKS_STATS = '$_USER_DATA/tracks_stats.json';
  static final LATEST_QUEUE = '$_USER_DATA/latest_queue.json';

  static final LOGS = '$_USER_DATA/logs.txt';

  static final TOTAL_LISTEN_TIME = '$_USER_DATA/total_listen.txt';
  static final FAVOURITES_PLAYLIST = '$_USER_DATA/favs.json';
  static final NAMIDA_LOGO = '${AppDirs.ARTWORKS}.ARTWORKS.NAMIDA_DEFAULT_ARTWORK.PNG';
}

/// Directories used by Namida
class AppDirs {
  static String USER_DATA = '';
  static String APP_CACHE = '';
  static String INTERNAL_STORAGE = '';

  static final HISTORY_PLAYLIST = '$USER_DATA/History/';
  static final PLAYLISTS = '$USER_DATA/Playlists/';
  static final QUEUES = '$USER_DATA/Queues/';
  static final ARTWORKS = '$USER_DATA/Artworks/';
  static final PALETTES = '$USER_DATA/Palettes/';
  static final VIDEOS_CACHE = '$USER_DATA/Videos/';
  static final VIDEOS_CACHE_TEMP = '$USER_DATA/Videos/Temp/';
  static final THUMBNAILS = '$USER_DATA/Thumbnails/';
  static final YT_THUMBNAILS = '$USER_DATA/YTThumbnails/';
  static final LYRICS = '$USER_DATA/Lyrics/';
  static final YT_METADATA = '$USER_DATA/Metadata/';
  static final YT_METADATA_COMMENTS = '$USER_DATA/Metadata/Comments/';
  static final YOUTUBE_STATS = '$USER_DATA/Youtube Stats/';
  static final COMPRESSED_IMAGES = '$INTERNAL_STORAGE/Compressed/';

  static final List<String> values = [
    HISTORY_PLAYLIST,
    PLAYLISTS,
    QUEUES,
    ARTWORKS,
    PALETTES,
    VIDEOS_CACHE,
    VIDEOS_CACHE_TEMP,
    THUMBNAILS,
    YT_THUMBNAILS,
    LYRICS,
    YT_METADATA,
    YT_METADATA_COMMENTS,
    YOUTUBE_STATS,
  ];
}

/// Default Playlists IDs
const k_PLAYLIST_NAME_FAV = '_FAVOURITES_';
const k_PLAYLIST_NAME_HISTORY = '_HISTORY_';
const k_PLAYLIST_NAME_MOST_PLAYED = '_MOST_PLAYED_';
const k_PLAYLIST_NAME_AUTO_GENERATED = '_AUTO_GENERATED_';

List<Track> get allTracksInLibrary => UnmodifiableListView(Indexer.inst.tracksInfoList);

bool get shouldAlbumBeSquared =>
    (SettingsController.inst.albumGridCount.value > 1 && !SettingsController.inst.useAlbumStaggeredGridView.value) ||
    (SettingsController.inst.albumGridCount.value == 1 && SettingsController.inst.forceSquaredAlbumThumbnail.value);

/// Stock Video Qualities List
final List<String> kStockVideoQualities = [
  '144p',
  '240p',
  '360p',
  '480p',
  '720p',
  '1080p',
  '2k',
  '4k',
  '8k',
];

/// Default values available for setting the Date Time Format.
const kDefaultDateTimeStrings = {
  'yyyyMMdd': '20220413',
  'dd/MM/yyyy': '13/04/2022',
  'MM/dd/yyyy': '04/13/2022',
  'yyyy/MM/dd': '2022/04/13',
  'yyyy/dd/MM': '2022/13/04',
  'dd-MM-yyyy': '13-04-2022',
  'MM-dd-yyyy': '04-13-2022',
  'MMMM dd, yyyy': 'April 13, 2022',
  'MMM dd, yyyy': 'Apr 13, 2022',
  '[dd | MM]': '[13 | 04]',
  '[dd.MM.yyyy]': '[13.04.2022]',
};

/// Extensions used to filter audio files
const List<String> kAudioFileExtensions = [
  '.aac',
  '.ac3',
  '.aiff',
  '.amr',
  '.ape',
  '.au',
  '.dts',
  '.flac',
  '.m4a',
  '.m4b',
  '.m4p',
  '.mid',
  '.mp3',
  '.ogg',
  '.opus',
  '.ra',
  '.tak',
  '.wav',
  '.wma',
];

/// Extensions used to filter video files
const List<String> kVideoFilesExtensions = [
  'mp4',
  'mkv',
  'avi',
  'wmv',
  'flv',
  'mov',
  '3gp',
  'ogv',
  'webm',
  'mpg',
  'mpeg',
  'm4v',
  'ts',
  'vob',
  'asf',
  'rm',
  'swf',
  'f4v',
  'divx',
  'm2ts',
  'mts',
  'mpv',
  'mp2',
  'mpe',
  'mpa',
  'mxf',
  'm2v',
  'mpeg1',
  'mpeg2',
  'mpeg4'
];
const kDefaultOrientations = <DeviceOrientation>[DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];
const kDefaultLang = NamidaLanguage(
  code: "en_US",
  name: "English",
  country: "United States",
);

const kDummyTrack = Track('');
const kDummyExtendedTrack = TrackExtended(
  title: "",
  originalArtist: "",
  artistsList: [],
  album: "",
  albumArtist: "",
  originalGenre: "",
  genresList: [],
  composer: "",
  trackNo: 0,
  duration: 0,
  year: 0,
  size: 0,
  dateAdded: 0,
  dateModified: 0,
  path: "",
  comment: "",
  bitrate: 0,
  sampleRate: 0,
  format: "",
  channels: "",
  discNo: 0,
  language: "",
  lyrics: "",
);

/// Unknown Tag Fields
class UnknownTags {
  static const TITLE = '';
  static const ALBUM = 'Unknown Album';
  static const ALBUMARTIST = '';
  static const ARTIST = 'Unknown Artist';
  static const GENRE = 'Unknown Genre';
  static const COMPOSER = 'Unknown Composer';
}

int get currentTimeMS => DateTime.now().millisecondsSinceEpoch;

const kThemeAnimationDurationMS = 350;

const kMaximumSleepTimerTracks = 40;
const kMaximumSleepTimerMins = 180;
