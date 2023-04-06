// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'package:flutter/material.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';

///
int kSdkVersion = 21;
String k_DIR_USER_DATA = '';
String k_DIR_APP_INTERNAL_STORAGE = '';

final Set<String> kStoragePaths = {};
final Set<String> kDirectoriesPaths = {};
final List<double> kDefaultWaveFormData = List<double>.generate(1000, (index) => 0.02);
final List<double> kDefaultScaleList = List<double>.generate(500, (index) => 0.01);
final RegExp kYoutubeRegex = RegExp(
  r'\b(?:https?://)?(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)([\w\-]+)(?:\S+)?',
  caseSensitive: false,
);

/// Main Color
Color kMainColor = const Color.fromARGB(160, 117, 128, 224);
Color kMainColorLight = const Color.fromARGB(255, 116, 126, 219);
Color kMainColorDark = const Color.fromARGB(255, 139, 149, 241);

/// Directories and files used by Namida
final String k_FILE_PATH_SETTINGS = '$k_DIR_USER_DATA/namidaSettings.json';
final String k_FILE_PATH_TRACKS = '$k_DIR_USER_DATA/tracks.json';
final String k_FILE_PATH_VIDEO_PATHS = '$k_DIR_USER_DATA/videoFilesPaths.txt';
final String k_FILE_PATH_YOUTUBE_STATS = '$k_DIR_USER_DATA/ytstats.json';
final String k_FILE_PATH_LATEST_QUEUE = '$k_DIR_USER_DATA/latestqueue.json';

final String k_PLAYLIST_PATH_HISTORY = '$k_DIR_USER_DATA/sussybaka.json';
final String k_PLAYLIST_PATH_HISTORY_BACKUP = '$k_DIR_USER_DATA/sussybakabk.json';
final String k_PLAYLIST_PATH_FAVOURITES = '$k_DIR_USER_DATA/favs.json';

final String k_DIR_PLAYLISTS = '$k_DIR_USER_DATA/Playlists/';
final String k_DIR_QUEUES = '$k_DIR_USER_DATA/Queues/';
final String k_DIR_ARTWORKS = '$k_DIR_USER_DATA/Artworks/';
final String k_DIR_PALETTES = '$k_DIR_USER_DATA/Palettes/';
final String k_DIR_WAVEFORMS = '$k_DIR_USER_DATA/Waveforms/';
final String k_DIR_VIDEOS_CACHE = '$k_DIR_USER_DATA/Videos/';
final String k_DIR_VIDEOS_CACHE_TEMP = '$k_DIR_USER_DATA/Videos/Temp/';
final String k_DIR_LYRICS = '$k_DIR_USER_DATA/Lyrics/';
final String k_DIR_YT_METADATA = '$k_DIR_USER_DATA/Metadata/';
final String k_DIR_YT_METADATA_COMMENTS = '$k_DIR_USER_DATA/Metadata/Comments/';

final String k_FILE_PATH_NAMIDA_LOGO = '$k_DIR_ARTWORKS.NAMIDA_DEFAULT_ARTWORK.PNG';

/// Dimensions
const double kBottomPadding = 102.0;
const Widget kBottomPaddingWidget = SizedBox(height: 102.0);

/// Default Playlists IDs
const k_PLAYLIST_NAME_FAV = '_FAVOURITES_';
const k_PLAYLIST_NAME_HISTORY = '_HISTORY_';
const k_PLAYLIST_NAME_MOST_PLAYED = '_MOST_PLAYED_';
const k_PLAYLIST_NAME_AUTO_GENERATED = '_AUTO_GENERATED_';

late final Playlist namidaHistoryPlaylist;
late final Playlist namidaFavouritePlaylist;
late final Playlist namidaMostPlayedPlaylist;

double get trackTileItemExtent => SettingsController.inst.trackListTileHeight.value + 4.0 * 3.0;
List<Track> get allTracksInLibrary => Indexer.inst.tracksInfoList.toList();

/// Stock Library Tabs List
final List<String> kLibraryTabsStock = [
  'albums',
  'tracks',
  'artists',
  'genres',
  'playlists',
  'folders',
];

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

/// Extensions used to filter files
const List<String> kFileExtensions = [
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
final kDummyTrack = Track(
  '',
  [''],
  '',
  '',
  [''],
  '',
  0,
  0,
  0,
  0,
  0,
  0,
  '0',
  '',
  0,
  0,
  '',
  '',
  0,
  '',
  '',
  '',
);
