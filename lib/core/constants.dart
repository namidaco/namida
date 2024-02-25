// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';

///
int kSdkVersion = 21;

final Set<String> kStoragePaths = {};
final Set<String> kInitialDirectoriesToScan = {};

/// Main Color
const Color kMainColor = Color.fromARGB(160, 117, 128, 224);
const Color kMainColorLight = Color.fromARGB(255, 116, 126, 219);
const Color kMainColorDark = Color.fromARGB(255, 139, 149, 241);

abstract class NamidaLinkRegex {
  static const url = r'https?://([\w-]+\.)+[\w-]+(/[\w-./?%&@\$=~#+]*)?';
  static const phoneNumber = r'[+0]\d+[\d-]+\d';
  static const email = r'[^@\s]+@([^@\s]+\.)+[^@\W]+';
  static const duration = r'\b(\d{1,2}:)?(\d{1,2}):(\d{2})\b';
  static const all = '($url|$duration|$phoneNumber|$email)';

  static final youtubeLinkRegex = RegExp(
    r'\b(?:https?://)?(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)([\w\-]+)(?:\S+)?',
    caseSensitive: false,
  );

  static final youtubeIdRegex = RegExp(
    r'((?:https?:)?\/\/)?((?:www|m)\.)?((?:youtube\.com|youtu.be))(\/(?:[\w\-]+\?v=|embed\/|v\/)?)([\w\-]+)(\S+)?',
    caseSensitive: false,
  );

  static final youtubePlaylistsLinkRegex = RegExp(
    r'\b(?:https?://)?(?:www\.)?(?:youtube\.com/playlist\?list=)([\w\-]+)(?:\S+)?',
    caseSensitive: false,
  );
}

class NamidaLinkUtils {
  NamidaLinkUtils._();

  static Duration? parseDuration(String url) {
    final match = RegExp(NamidaLinkRegex.duration).firstMatch(url);
    if (match != null && match.groupCount > 1) {
      Duration? dur;
      try {
        if (match.groupCount == 3) {
          dur = Duration(
            hours: int.parse(match[1]!.split(':').first),
            minutes: int.parse(match[2]!),
            seconds: int.parse(match[3]!),
          );
        } else if (match.groupCount == 2) {
          dur = Duration(
            minutes: int.parse(match[1]!),
            seconds: int.parse(match[2]!),
          );
        }
        return dur;
      } catch (_) {}
    }
    return null;
  }

  static Future<bool> openLink(String url) async {
    bool didLaunch = false;
    try {
      didLaunch = await launchUrlString(url, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {}
    if (!didLaunch) {
      try {
        didLaunch = await launchUrlString(url);
      } catch (_) {}
    }
    return didLaunch;
  }
}

/// Files used by Namida
class AppPaths {
  static final _USER_DATA = AppDirs.USER_DATA;

  // ================= User Data =================
  static final SETTINGS = '$_USER_DATA/namida_settings.json';
  static final SETTINGS_EQUALIZER = '$_USER_DATA/namida_settings_eq.json';
  static final SETTINGS_PLAYER = '$_USER_DATA/namida_settings_player.json';
  static final TRACKS = '$_USER_DATA/tracks.json';
  static final VIDEOS_LOCAL = '$_USER_DATA/local_videos.json';
  static final VIDEOS_CACHE = '$_USER_DATA/cache_videos.json';
  static final TRACKS_STATS = '$_USER_DATA/tracks_stats.json';
  static final LATEST_QUEUE = '$_USER_DATA/latest_queue.json';

  static final LOGS = '$_USER_DATA/logs.txt';
  static final LOGS_TAGGER = '$_USER_DATA/tagger_logs.txt';

  static final TOTAL_LISTEN_TIME = '$_USER_DATA/total_listen.txt';
  static final FAVOURITES_PLAYLIST = '$_USER_DATA/favs.json';
  static final NAMIDA_LOGO = '${AppDirs.ARTWORKS}.ARTWORKS.NAMIDA_DEFAULT_ARTWORK.PNG';

  // ================= Youtube =================
  static final YT_LIKES_PLAYLIST = '${AppDirs.YOUTUBE_MAIN_DIRECTORY}/yt_likes.json';
  static final YT_SUBSCRIPTIONS = '${AppDirs.YOUTUBE_MAIN_DIRECTORY}/yt_subs.json';
}

/// Directories used by Namida
class AppDirs {
  static String USER_DATA = '';
  static String APP_CACHE = '';
  static String INTERNAL_STORAGE = '';

  // ================= User Data =================
  static final HISTORY_PLAYLIST = '$USER_DATA/History/';
  static final PLAYLISTS = '$USER_DATA/Playlists/';
  static final QUEUES = '$USER_DATA/Queues/';
  static final ARTWORKS = '$USER_DATA/Artworks/'; // extracted audio artworks
  static final PALETTES = '$USER_DATA/Palettes/';
  static final VIDEOS_CACHE = '$USER_DATA/Videos/';
  static final AUDIOS_CACHE = '$USER_DATA/Audios/';
  static final VIDEOS_CACHE_TEMP = '$USER_DATA/Videos/Temp/';
  static final THUMBNAILS = '$USER_DATA/Thumbnails/'; // extracted video thumbnails
  static final LYRICS = '$USER_DATA/Lyrics/';
  static final M3UBackup = '$USER_DATA/M3U Backup/'; // backups m3u on first found

  // ================= Internal Storage =================
  static final SAVED_ARTWORKS = '$INTERNAL_STORAGE/Artworks/';
  static final BACKUPS = '$INTERNAL_STORAGE/Backups'; // only one without ending slash.
  static final COMPRESSED_IMAGES = '$INTERNAL_STORAGE/Compressed/';
  static final M3UPlaylists = '$INTERNAL_STORAGE/M3U Playlists/';
  static final YOUTUBE_DOWNLOADS_DEFAULT = '$INTERNAL_STORAGE/Downloads/';
  static String get YOUTUBE_DOWNLOADS => settings.ytDownloadLocation.value;

  // ================= Youtube =================
  static final YOUTUBE_MAIN_DIRECTORY = '$USER_DATA/Youtube';

  static final YT_PLAYLISTS = '$YOUTUBE_MAIN_DIRECTORY/Youtube Playlists/';
  static final YT_HISTORY_PLAYLIST = '$YOUTUBE_MAIN_DIRECTORY/Youtube History/';
  static final YT_THUMBNAILS = '$YOUTUBE_MAIN_DIRECTORY/YTThumbnails/';
  static final YT_THUMBNAILS_CHANNELS = '$YOUTUBE_MAIN_DIRECTORY/YTThumbnails Channels/';
  static final YT_METADATA = '$YOUTUBE_MAIN_DIRECTORY/Metadata Videos/';
  static final YT_METADATA_TEMP = '$YOUTUBE_MAIN_DIRECTORY/Metadata Videos Temp/';
  static final YT_METADATA_CHANNELS = '$YOUTUBE_MAIN_DIRECTORY/Metadata Channels/';
  static final YT_METADATA_COMMENTS = '$YOUTUBE_MAIN_DIRECTORY/Metadata Comments/';
  static final YT_STATS = '$YOUTUBE_MAIN_DIRECTORY/Youtube Stats/';
  static final YT_PALETTES = '$YOUTUBE_MAIN_DIRECTORY/Palettes/';
  static final YT_DOWNLOAD_TASKS = '$YOUTUBE_MAIN_DIRECTORY/Download Tasks/';

  // ===========================================
  static final List<String> values = [
    // -- User Data
    HISTORY_PLAYLIST,
    PLAYLISTS,
    QUEUES,
    ARTWORKS,
    PALETTES,
    VIDEOS_CACHE,
    VIDEOS_CACHE_TEMP,
    AUDIOS_CACHE,
    THUMBNAILS,
    LYRICS,
    M3UBackup,
    // -- Youtube
    YOUTUBE_MAIN_DIRECTORY,
    YT_PLAYLISTS,
    YT_HISTORY_PLAYLIST,
    YT_THUMBNAILS,
    YT_THUMBNAILS_CHANNELS,
    YT_METADATA,
    YT_METADATA_TEMP,
    YT_METADATA_CHANNELS,
    YT_METADATA_COMMENTS,
    YT_STATS,
    YT_PALETTES,
    YT_DOWNLOAD_TASKS,
    // Internal Storage Directories are created on demand
  ];
}

class AppSocial {
  static const APP_VERSION = 'v2.0.1-release';
  static const DONATE_KOFI = 'https://ko-fi.com/namidaco';
  static const DONATE_BUY_ME_A_COFFEE = 'https://www.buymeacoffee.com/namidaco';
  static const GITHUB = 'https://github.com/namidaco/namida';
  static const GITHUB_ISSUES = '$GITHUB/issues';
  static const GITHUB_RELEASES = '$GITHUB/releases/';
  static const EMAIL = 'namida.coo@gmail.com';
  static const TRANSLATION_REPO = 'https://github.com/namidaco/namida-translations';
}

class LibraryCategory {
  static const localTracks = 'tr';
  static const localVideos = 'vid';
  static const youtube = 'yt';
}

/// Default Playlists IDs
const k_PLAYLIST_NAME_FAV = '_FAVOURITES_';
const k_PLAYLIST_NAME_HISTORY = '_HISTORY_';
const k_PLAYLIST_NAME_MOST_PLAYED = '_MOST_PLAYED_';
const k_PLAYLIST_NAME_AUTO_GENERATED = '_AUTO_GENERATED_';

List<Track> get allTracksInLibrary => UnmodifiableListView(Indexer.inst.tracksInfoList);

bool get shouldAlbumBeSquared =>
    (settings.albumGridCount.value > 1 && !settings.useAlbumStaggeredGridView.value) || (settings.albumGridCount.value == 1 && settings.forceSquaredAlbumThumbnail.value);

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
const Set<String> kAudioFileExtensions = {
  '.m4a',
  '.mp3',
  '.weba',
  '.ogg',
  '.wav',
  '.flac',
  '.aac',
  '.3gp',
  '.ac3',
  '.opus',
  '.m4b',
  '.pk',
  '.8svx',
  '.aa',
  '.aax',
  '.act',
  '.aiff',
  '.alac',
  '.amr',
  '.ape',
  '.au',
  '.awb',
  '.cda',
  '.dss',
  '.dts',
  '.dvf',
  '.gsm',
  '.iklax',
  '.ivs',
  '.m4p',
  '.mmf',
  '.movpkg',
  '.mid',
  '.mpc',
  '.msv',
  '.nmf',
  '.oga',
  '.mogg',
  '.ra',
  '.rm',
  '.raw',
  '.rf64',
  '.sln',
  '.tak',
  '.tta',
  '.voc',
  '.vox',
  '.wma',
  '.wv',
  '.aif',
  '.aifc',
  '.amz',
  '.awc',
  '.bwf',
  '.caf',
  '.dct',
  '.dff',
  '.dsf',
  '.fap',
  '.flp',
  '.its',
  '.kar',
  '.kfn',
  '.m4r',
  '.mac',
  '.mka',
  '.mlp',
  '.mp2',
  '.mpp',
  '.oma',
  '.qcp',
  '.rmi',
  '.snd',
  '.spx',
  '.ts',
  '.uax',
  '.xmz',
};

/// Extensions used to filter video files
const Set<String> kVideoFilesExtensions = {
  '.mp4',
  '.mkv',
  '.avi',
  '.wmv',
  '.flv',
  '.mov',
  '.3gp',
  '.ogv',
  '.webm',
  '.mpg',
  '.mpeg',
  '.m4v',
  '.ts',
  '.vob',
  '.asf',
  '.rm',
  '.swf',
  '.f4v',
  '.divx',
  '.m2ts',
  '.mts',
  '.mpv',
  '.mp2',
  '.mpe',
  '.mpa',
  '.mxf',
  '.m2v',
  '.mpeg1',
  '.mpeg2',
  '.mpeg4'
};

/// Extensions used to filter m3u files
const Set<String> kM3UPlaylistsExtensions = {'.m3u', '.m3u8', '.M3U', '.M3U8'};

const Set<String> kImageFilesExtensions = {'.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp'};

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
  originalMood: "",
  moodList: [],
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
  static const MOOD = '';
  static const COMPOSER = 'Unknown Composer';
}

int get currentTimeMS => DateTime.now().millisecondsSinceEpoch;

const kThemeAnimationDurationMS = 350;

const kMaximumSleepTimerTracks = 40;
const kMaximumSleepTimerMins = 180;
