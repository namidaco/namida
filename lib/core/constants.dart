// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/version_wrapper.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';

class NamidaDeviceInfo {
  static int sdkVersion = 21;

  static String? _deviceId;

  static final androidInfoCompleter = Completer<AndroidDeviceInfo>();
  static final packageInfoCompleter = Completer<PackageInfo>();

  static AndroidDeviceInfo? androidInfo;
  static PackageInfo? packageInfo;

  static VersionWrapper? version;
  static String? buildType;

  static bool _fetchedAndroidInfo = false;
  static bool _fetchedPackageInfo = false;

  static Future<void> fetchAndroidInfo() async {
    if (_fetchedAndroidInfo) return;
    _fetchedAndroidInfo = true;
    try {
      final res = await DeviceInfoPlugin().androidInfo;
      androidInfo = res;
      androidInfoCompleter.complete(res);
    } catch (_) {
      _fetchedAndroidInfo = false;
    }
  }

  static Future<String?> fetchDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    try {
      if (Platform.isWindows) {
        _deviceId = await _getWindowsUDID();
      } else {
        _deviceId = await FlutterUdid.udid;
      }
    } catch (_) {}
    return _deviceId;
  }

  // native call causes debug connection to get lost, this works fine
  // source: https://github.com/BestBurning/platform_device_id/issues/21#issuecomment-1133934641
  static Future<String> _getWindowsUDID() async {
    String biosID = '';
    final process = await Process.start(
      'wmic',
      ['csproduct', 'get', 'uuid'],
      mode: ProcessStartMode.detachedWithStdio,
    );
    final result = await process.stdout.transform(utf8.decoder).toList();
    for (var element in result) {
      final item = element.replaceAll(RegExp('\r|\n|\\s|UUID|uuid'), '');
      if (item.isNotEmpty) {
        biosID = item;
      }
    }
    return biosID;
  }

  static Future<void> fetchPackageInfo() async {
    if (_fetchedPackageInfo) return;
    _fetchedPackageInfo = true;
    try {
      final res = await PackageInfo.fromPlatform();
      packageInfo = res;
      version = VersionWrapper(res.version, res.buildNumber);
      packageInfoCompleter.complete(res);
    } catch (_) {
      _fetchedPackageInfo = false;
    }
  }
}

final kStoragePaths = <String>[];

/// Main Color
const Color kMainColorLight = Color(0xFF9c99c1);
const Color kMainColorDark = Color(0xFF4e4c72);

const isKuru = bool.fromEnvironment('IS_KURU_BUILD');

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
            hours: int.parse(match[1]!.splitFirst(':')),
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

  static Future<bool> openLinkPreferNamida(String url) {
    final didOpen = tryOpeningPlaylistOrVideo(url);
    if (didOpen) return Future.value(true);
    return openLink(url);
  }

  static bool tryOpeningPlaylistOrVideo(String url) {
    final possiblePlaylistId = NamidaLinkUtils.extractPlaylistId(url);
    if (possiblePlaylistId != null && possiblePlaylistId.isNotEmpty) {
      YTHostedPlaylistSubpage.fromId(
        playlistId: possiblePlaylistId,
        userPlaylist: null,
      ).navigate();
      return true;
    }

    final possibleVideoId = NamidaLinkUtils.extractYoutubeId(url);
    if (possibleVideoId != null && possibleVideoId.isNotEmpty) {
      OnYoutubeLinkOpenAction.alwaysAsk.execute([possibleVideoId]);
      return true;
    }
    return false;
  }

  static String? extractYoutubeLink(String text) {
    try {
      return NamidaLinkRegex.youtubeLinkRegex.firstMatch(text)?[0];
    } catch (_) {}
    return null;
  }

  static String? extractYoutubeId(String text) {
    final link = extractYoutubeLink(text);
    if (link == null || link.isEmpty) return null;

    try {
      final possibleId = NamidaLinkRegex.youtubeIdRegex.firstMatch(link)?.group(5);
      if (possibleId == null || possibleId.length != 11) return '';
      return possibleId;
    } catch (_) {}

    return null;
  }

  static String? extractPlaylistId(String playlistUrl) {
    try {
      return NamidaLinkRegex.youtubePlaylistsLinkRegex.firstMatch(playlistUrl)?.group(1);
    } catch (_) {}
    return null;
  }
}

enum AppPathsBackupEnum {
  // ================= User Data =================
  SETTINGS,
  SETTINGS_EQUALIZER,
  SETTINGS_PLAYER,
  SETTINGS_YOUTUBE,
  SETTINGS_EXTRA,
  SETTINGS_TUTORIAL,
  TRACKS_DB_INFO,
  TRACKS_STATS_DB_INFO,
  VIDEOS_LOCAL_DB_INFO,
  VIDEOS_CACHE_DB_INFO,
  LATEST_QUEUE,

  // -- obsolete
  TRACKS_OLD,
  TRACKS_STATS_OLD,
  VIDEOS_LOCAL_OLD,
  VIDEOS_CACHE_OLD,
  // ---------

  TOTAL_LISTEN_TIME,
  FAVOURITES_PLAYLIST,

  // ================= Youtube =================
  YT_LIKES_PLAYLIST,
  YT_SUBSCRIPTIONS,
  YT_SUBSCRIPTIONS_GROUPS_ALL,
  VIDEO_ID_STATS_DB_INFO,
  CACHE_VIDEOS_PRIORITY,

  // ------======== Directories ========------
  // ================= User Data =================
  HISTORY_PLAYLIST(true),
  PLAYLISTS(true),
  PLAYLISTS_ARTWORKS(true),
  QUEUES(true),
  ARTWORKS(true),
  PALETTES(true),
  VIDEOS_CACHE(true),
  AUDIOS_CACHE(true),
  THUMBNAILS(true),
  LYRICS(true),
  M3UBackup(true),
  RECENTLY_DELETED(true),

  // ================= Youtube =================

  YOUTIPIE_CACHE(true),

  YT_PLAYLISTS(true),
  YT_PLAYLISTS_ARTWORKS(true),
  YT_HISTORY_PLAYLIST(true),
  YT_THUMBNAILS(true),
  YT_THUMBNAILS_CHANNELS(true),

  YT_STATS(true),
  YT_PALETTES(true),
  YT_DOWNLOAD_TASKS(true),
  ;

  final bool isDir;
  const AppPathsBackupEnum([this.isDir = false]);

  String resolve() {
    return switch (this) {
      AppPathsBackupEnum.SETTINGS => AppPaths.SETTINGS,
      AppPathsBackupEnum.SETTINGS_EQUALIZER => AppPaths.SETTINGS_EQUALIZER,
      AppPathsBackupEnum.SETTINGS_PLAYER => AppPaths.SETTINGS_PLAYER,
      AppPathsBackupEnum.SETTINGS_YOUTUBE => AppPaths.SETTINGS_YOUTUBE,
      AppPathsBackupEnum.SETTINGS_EXTRA => AppPaths.SETTINGS_EXTRA,
      AppPathsBackupEnum.SETTINGS_TUTORIAL => AppPaths.SETTINGS_TUTORIAL,
      AppPathsBackupEnum.TRACKS_DB_INFO => AppPaths.TRACKS_DB_INFO.file.path,
      AppPathsBackupEnum.TRACKS_STATS_DB_INFO => AppPaths.TRACKS_STATS_DB_INFO.file.path,
      AppPathsBackupEnum.VIDEOS_LOCAL_DB_INFO => AppPaths.VIDEOS_LOCAL_DB_INFO.file.path,
      AppPathsBackupEnum.VIDEOS_CACHE_DB_INFO => AppPaths.VIDEOS_CACHE_DB_INFO.file.path,
      AppPathsBackupEnum.LATEST_QUEUE => AppPaths.LATEST_QUEUE,
      AppPathsBackupEnum.TRACKS_OLD => AppPaths.TRACKS_OLD,
      AppPathsBackupEnum.TRACKS_STATS_OLD => AppPaths.TRACKS_STATS_OLD,
      AppPathsBackupEnum.VIDEOS_LOCAL_OLD => AppPaths.VIDEOS_LOCAL_OLD,
      AppPathsBackupEnum.VIDEOS_CACHE_OLD => AppPaths.VIDEOS_CACHE_OLD,
      AppPathsBackupEnum.TOTAL_LISTEN_TIME => AppPaths.TOTAL_LISTEN_TIME,
      AppPathsBackupEnum.FAVOURITES_PLAYLIST => AppPaths.FAVOURITES_PLAYLIST,
      AppPathsBackupEnum.YT_LIKES_PLAYLIST => AppPaths.YT_LIKES_PLAYLIST,
      AppPathsBackupEnum.YT_SUBSCRIPTIONS => AppPaths.YT_SUBSCRIPTIONS,
      AppPathsBackupEnum.YT_SUBSCRIPTIONS_GROUPS_ALL => AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL,
      AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO => AppPaths.VIDEO_ID_STATS_DB_INFO.file.path,
      AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY => AppPaths.CACHE_VIDEOS_PRIORITY.file.path,
      AppPathsBackupEnum.HISTORY_PLAYLIST => AppDirs.HISTORY_PLAYLIST,
      AppPathsBackupEnum.PLAYLISTS => AppDirs.PLAYLISTS,
      AppPathsBackupEnum.PLAYLISTS_ARTWORKS => AppDirs.PLAYLISTS_ARTWORKS,
      AppPathsBackupEnum.QUEUES => AppDirs.QUEUES,
      AppPathsBackupEnum.ARTWORKS => AppDirs.ARTWORKS,
      AppPathsBackupEnum.PALETTES => AppDirs.PALETTES,
      AppPathsBackupEnum.VIDEOS_CACHE => AppDirs.VIDEOS_CACHE,
      AppPathsBackupEnum.AUDIOS_CACHE => AppDirs.AUDIOS_CACHE,
      AppPathsBackupEnum.THUMBNAILS => AppDirs.THUMBNAILS,
      AppPathsBackupEnum.LYRICS => AppDirs.LYRICS,
      AppPathsBackupEnum.M3UBackup => AppDirs.M3UBackup,
      AppPathsBackupEnum.RECENTLY_DELETED => AppDirs.RECENTLY_DELETED,
      AppPathsBackupEnum.YOUTIPIE_CACHE => AppDirs.YOUTIPIE_CACHE,
      AppPathsBackupEnum.YT_PLAYLISTS => AppDirs.YT_PLAYLISTS,
      AppPathsBackupEnum.YT_PLAYLISTS_ARTWORKS => AppDirs.YT_PLAYLISTS_ARTWORKS,
      AppPathsBackupEnum.YT_HISTORY_PLAYLIST => AppDirs.YT_HISTORY_PLAYLIST,
      AppPathsBackupEnum.YT_THUMBNAILS => AppDirs.YT_THUMBNAILS,
      AppPathsBackupEnum.YT_THUMBNAILS_CHANNELS => AppDirs.YT_THUMBNAILS_CHANNELS,
      AppPathsBackupEnum.YT_STATS => AppDirs.YT_STATS,
      AppPathsBackupEnum.YT_PALETTES => AppDirs.YT_PALETTES,
      AppPathsBackupEnum.YT_DOWNLOAD_TASKS => AppDirs.YT_DOWNLOAD_TASKS,
    };
  }
}

class AppPathsBackupEnumCategories {
  const AppPathsBackupEnumCategories._();

  static List<AppPathsBackupEnum> database = [
    AppPathsBackupEnum.TRACKS_OLD,
    AppPathsBackupEnum.TRACKS_DB_INFO,
    AppPathsBackupEnum.TRACKS_STATS_OLD,
    AppPathsBackupEnum.TRACKS_STATS_DB_INFO,
    AppPathsBackupEnum.TOTAL_LISTEN_TIME,
    AppPathsBackupEnum.VIDEOS_CACHE_OLD,
    AppPathsBackupEnum.VIDEOS_CACHE_DB_INFO,
    AppPathsBackupEnum.VIDEOS_LOCAL_OLD,
    AppPathsBackupEnum.VIDEOS_LOCAL_DB_INFO,
    AppPathsBackupEnum.YT_DOWNLOAD_TASKS,
    AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO,
    AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY,
  ];
  static List<AppPathsBackupEnum> database_yt = [
    AppPathsBackupEnum.YT_STATS,
  ];

  static List<AppPathsBackupEnum> playlists = [
    AppPathsBackupEnum.PLAYLISTS,
    AppPathsBackupEnum.PLAYLISTS_ARTWORKS,
    AppPathsBackupEnum.FAVOURITES_PLAYLIST,
  ];
  static List<AppPathsBackupEnum> playlists_yt = [
    AppPathsBackupEnum.YT_PLAYLISTS,
    AppPathsBackupEnum.YT_PLAYLISTS_ARTWORKS,
    AppPathsBackupEnum.YT_LIKES_PLAYLIST,
  ];

  static List<AppPathsBackupEnum> history = [
    AppPathsBackupEnum.HISTORY_PLAYLIST,
  ];
  static List<AppPathsBackupEnum> history_yt = [
    AppPathsBackupEnum.YT_HISTORY_PLAYLIST,
  ];

  static List<AppPathsBackupEnum> settings = [
    AppPathsBackupEnum.SETTINGS,
    AppPathsBackupEnum.SETTINGS_EQUALIZER,
    AppPathsBackupEnum.SETTINGS_EXTRA,
    AppPathsBackupEnum.SETTINGS_PLAYER,
    AppPathsBackupEnum.SETTINGS_TUTORIAL,
    AppPathsBackupEnum.SETTINGS_YOUTUBE,
  ];

  static List<AppPathsBackupEnum> lyrics = [
    AppPathsBackupEnum.LYRICS,
  ];

  static List<AppPathsBackupEnum> queues = [
    AppPathsBackupEnum.QUEUES,
    AppPathsBackupEnum.LATEST_QUEUE,
  ];

  static List<AppPathsBackupEnum> palette = [
    AppPathsBackupEnum.PALETTES,
  ];

  static List<AppPathsBackupEnum> palette_yt = [
    AppPathsBackupEnum.YT_PALETTES,
  ];

  static List<AppPathsBackupEnum> videos_cache = [
    AppPathsBackupEnum.VIDEOS_CACHE,
  ];

  static List<AppPathsBackupEnum> audios_cache = [
    AppPathsBackupEnum.AUDIOS_CACHE,
  ];

  static List<AppPathsBackupEnum> artworks = [
    AppPathsBackupEnum.ARTWORKS,
  ];

  static List<AppPathsBackupEnum> thumbnails = [
    AppPathsBackupEnum.THUMBNAILS,
  ];
  static List<AppPathsBackupEnum> thumbnails_yt = [
    AppPathsBackupEnum.YT_THUMBNAILS,
    AppPathsBackupEnum.YT_THUMBNAILS_CHANNELS,
  ];

  static List<AppPathsBackupEnum> youtipie_cache = [
    AppPathsBackupEnum.YOUTIPIE_CACHE,
  ];
}

/// Files used by Namida
class AppPaths {
  static String get _USER_DATA => AppDirs.USER_DATA;

  static String _join(String part1, String part2, [String? part3]) {
    return FileParts.joinPath(part1, part2, part3);
  }

  // ================= User Data =================
  static final SETTINGS = _join(_USER_DATA, 'namida_settings.json');
  static final SETTINGS_EQUALIZER = _join(_USER_DATA, 'namida_settings_eq.json');
  static final SETTINGS_PLAYER = _join(_USER_DATA, 'namida_settings_player.json');
  static final SETTINGS_YOUTUBE = _join(_USER_DATA, 'namida_settings_youtube.json');
  static final SETTINGS_EXTRA = _join(_USER_DATA, 'namida_settings_extra.json');
  static final SETTINGS_TUTORIAL = _join(_USER_DATA, 'namida_settings_tutorial.json');
  static final TRACKS_DB_INFO = DbWrapperFileInfo(directory: _USER_DATA, dbName: 'tracks');
  static final TRACKS_STATS_DB_INFO = DbWrapperFileInfo(directory: _USER_DATA, dbName: 'tracks_stats');
  static final VIDEOS_LOCAL_DB_INFO = DbWrapperFileInfo(directory: _USER_DATA, dbName: 'local_videos');
  static final VIDEOS_CACHE_DB_INFO = DbWrapperFileInfo(directory: _USER_DATA, dbName: 'cache_videos');
  static final LATEST_QUEUE = _join(_USER_DATA, 'latest_queue.json');

  // -- obsolete
  static final TRACKS_OLD = _join(_USER_DATA, 'tracks.json');
  static final TRACKS_STATS_OLD = _join(_USER_DATA, 'tracks_stats.json');
  static final VIDEOS_LOCAL_OLD = _join(_USER_DATA, 'local_videos.json');
  static final VIDEOS_CACHE_OLD = _join(_USER_DATA, 'cache_videos.json');
  // ---------

  static String get LOGS => _getLogsFile('');
  static String get LOGS_TAGGER => _getLogsFile('_tagger');

  static String _getLogsFile(String identifier) {
    final suffix = getLogsSuffix() ?? '_unknown';
    return '${AppDirs.LOGS_DIRECTORY}logs$identifier$suffix.txt';
  }

  static String? getLogsSuffix() {
    final info = NamidaDeviceInfo.packageInfo;
    if (info == null) return null;
    return '_${info.version}_${info.buildNumber}';
  }

  static final TOTAL_LISTEN_TIME = _join(_USER_DATA, 'total_listen.txt');
  static final FAVOURITES_PLAYLIST = _join(_USER_DATA, 'favs.json');
  static final NAMIDA_LOGO = '${AppDirs.ARTWORKS}.ARTWORKS.NAMIDA_DEFAULT_ARTWORK.PNG';
  static final NAMIDA_LOGO_MONET = '${AppDirs.ARTWORKS}.ARTWORKS.NAMIDA_DEFAULT_ARTWORK_MONET.PNG';

  // ================= Youtube =================
  static final YT_LIKES_PLAYLIST = _join(AppDirs.YOUTUBE_MAIN_DIRECTORY, 'yt_likes.json');
  static final YT_SUBSCRIPTIONS = _join(AppDirs.YOUTUBE_MAIN_DIRECTORY, 'yt_subs.json');
  static final YT_SUBSCRIPTIONS_GROUPS_ALL = _join(AppDirs.YOUTUBE_MAIN_DIRECTORY, 'yt_sub_groups.json');
  static final VIDEO_ID_STATS_DB_INFO = DbWrapperFileInfo(directory: AppDirs.YOUTUBE_MAIN_DIRECTORY, dbName: 'ytid_stats');
  static final CACHE_VIDEOS_PRIORITY = DbWrapperFileInfo(directory: _USER_DATA, dbName: 'cache_videos_priority');
}

/// Directories used by Namida
class AppDirs {
  static String ROOT_DIR = '';
  static String USER_DATA = '';
  static String APP_CACHE = '';
  static String INTERNAL_STORAGE = '';

  static final _sep = Platform.pathSeparator;
  static String _join(String part1, String part2, [String? part3]) {
    return FileParts.joinPath(part1, part2, part3) + _sep;
  }

  // ================= User Data =================
  static final HISTORY_PLAYLIST = _join(USER_DATA, 'History');
  static final PLAYLISTS = _join(USER_DATA, 'Playlists');
  static final PLAYLISTS_ARTWORKS = _join(USER_DATA, 'Playlists Artworks');
  static final QUEUES = _join(USER_DATA, 'Queues');
  static final ARTWORKS = _join(USER_DATA, 'Artworks'); // extracted audio artworks
  static final PALETTES = _join(USER_DATA, 'Palettes');
  static final VIDEOS_CACHE = _join(USER_DATA, 'Videos');
  static final AUDIOS_CACHE = _join(USER_DATA, 'Audios');
  static final VIDEOS_CACHE_TEMP = _join(USER_DATA, 'Videos', 'Temp');
  static final THUMBNAILS = _join(USER_DATA, 'Thumbnails'); // extracted video thumbnails
  static final LYRICS = _join(USER_DATA, 'Lyrics');
  static final M3UBackup = _join(USER_DATA, 'M3U Backup'); // backups m3u on first found
  static final RECENTLY_DELETED = _join(USER_DATA, 'Recently Deleted'); // stores files that was deleted recently
  static String get LOGS_DIRECTORY => _join(USER_DATA, 'Logs');

  // ================= Internal Storage =================
  static final SAVED_ARTWORKS = _join(INTERNAL_STORAGE, 'Artworks');
  static final BACKUPS = _join(INTERNAL_STORAGE, 'Backups'); // only one without ending slash.
  static final COMPRESSED_IMAGES = _join(INTERNAL_STORAGE, 'Compressed');
  static final M3UPlaylists = _join(INTERNAL_STORAGE, 'M3U Playlists');
  static final YOUTUBE_DOWNLOADS_DEFAULT = _join(INTERNAL_STORAGE, 'Downloads');
  static String get YOUTUBE_DOWNLOADS => settings.youtube.ytDownloadLocation.value;

  // ================= Youtube =================
  static final YOUTUBE_MAIN_DIRECTORY = _join(USER_DATA, 'Youtube');

  static final YOUTIPIE_CACHE = _join(YOUTUBE_MAIN_DIRECTORY, 'Youtipie');
  static final YOUTIPIE_DATA = _join(ROOT_DIR, 'Youtipie', 'Youtipie_data'); // this should never be accessed/backed up etc.

  static final YT_PLAYLISTS = _join(YOUTUBE_MAIN_DIRECTORY, 'Youtube Playlists');
  static final YT_PLAYLISTS_ARTWORKS = _join(YOUTUBE_MAIN_DIRECTORY, 'Youtube Playlists Artworks');
  static final YT_HISTORY_PLAYLIST = _join(YOUTUBE_MAIN_DIRECTORY, 'Youtube History');
  static final YT_THUMBNAILS = _join(YOUTUBE_MAIN_DIRECTORY, 'YTThumbnails');
  static final YT_THUMBNAILS_CHANNELS = _join(YOUTUBE_MAIN_DIRECTORY, 'YTThumbnails Channels');

  static final YT_STATS = _join(YOUTUBE_MAIN_DIRECTORY, 'Youtube Stats');
  static final YT_PALETTES = _join(YOUTUBE_MAIN_DIRECTORY, 'Palettes');
  static final YT_DOWNLOAD_TASKS = _join(YOUTUBE_MAIN_DIRECTORY, 'Download Tasks');

  // ===========================================
  static final List<String> values = [
    // -- User Data
    HISTORY_PLAYLIST,
    PLAYLISTS,
    PLAYLISTS_ARTWORKS,
    QUEUES,
    ARTWORKS,
    PALETTES,
    VIDEOS_CACHE,
    VIDEOS_CACHE_TEMP,
    AUDIOS_CACHE,
    THUMBNAILS,
    LYRICS,
    M3UBackup,
    RECENTLY_DELETED,
    LOGS_DIRECTORY,
    // -- Youtube
    YOUTUBE_MAIN_DIRECTORY,
    YT_PLAYLISTS,
    YT_PLAYLISTS_ARTWORKS,
    YT_HISTORY_PLAYLIST,
    YT_THUMBNAILS,
    YT_THUMBNAILS_CHANNELS,

    YOUTIPIE_CACHE,

    YT_STATS,
    YT_PALETTES,
    YT_DOWNLOAD_TASKS,
    // Internal Storage Directories are created on demand
  ];
}

class AppSocial {
  static const DONATE_KOFI = 'https://ko-fi.com/namidaco';
  static const DONATE_BUY_ME_A_COFFEE = 'https://www.buymeacoffee.com/namidaco';
  static const DONATE_PATREON = 'https://www.patreon.com/namidaco';
  static const GITHUB = 'https://github.com/namidaco/namida';
  static const GITHUB_SNAPSHOTS = 'https://github.com/namidaco/namida-snapshots';
  static const GITHUB_ISSUES = '$GITHUB/issues';
  static const GITHUB_RELEASES = '$GITHUB/releases/';
  static const GITHUB_RELEASES_BETA = '$GITHUB_SNAPSHOTS/releases/';
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

List<Track> get allTracksInLibrary => Indexer.inst.tracksInfoList.value;

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

class NamidaFileExtensionsWrapper {
  final Set<String> extensions;
  const NamidaFileExtensionsWrapper._(this.extensions);

  bool isPathValid(String path) {
    return isExtensionValid(path.splitLast('.'));
  }

  bool isExtensionValid(String ext) {
    return extensions.contains(ext);
  }

  static const _audioExtensions = {
    'm4a', 'mp3', 'weba', 'ogg', 'wav', 'flac', 'aac', 'ac3', 'opus', 'm4b', 'pk', '8svx', 'aa', 'aax', 'act', 'aiff', 'alac', 'amr', //
    'ape', 'au', 'awb', 'cda', 'dss', 'dts', 'dvf', 'gsm', 'iklax', 'ivs', 'm4p', 'mmf', 'movpkg', 'mid', 'mpc', 'msv', 'nmf', 'oga', //
    'mogg', 'ra', 'raw', 'rf64', 'sln', 'tak', 'tta', 'voc', 'vox', 'wma', 'wv', 'aif', 'aifc', 'amz', 'awc', 'bwf', 'caf', 'dct', 'dff', //
    'dsf', 'fap', 'flp', 'its', 'kar', 'kfn', 'm4r', 'mac', 'mka', 'mlp', 'mp2', 'mpp', 'oma', 'qcp', 'rmi', 'snd', 'spx', 'uax', 'xmz',
  };

  static const _videoExtensions = {
    'mp4', 'mkv', 'avi', 'wmv', 'flv', 'mov', '3gp', 'ogv', 'webm', 'mpg', 'mpeg', 'm4v', 'ts', 'vob', 'asf', //
    'rm', 'swf', 'f4v', 'divx', 'm2ts', 'mts', 'mpv', 'mpe', 'mpa', 'mxf', 'm2v', 'mpeg1', 'mpeg2', 'mpeg4'
  };

  static const audio = NamidaFileExtensionsWrapper._(_audioExtensions);
  static const video = NamidaFileExtensionsWrapper._(_videoExtensions);
  static const audioAndVideo = NamidaFileExtensionsWrapper._({..._audioExtensions, ..._videoExtensions});

  static const image = NamidaFileExtensionsWrapper._({'png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp'});

  static const m3u = NamidaFileExtensionsWrapper._({'m3u', 'm3u8', 'M3U', 'M3U8'});
  static const csv = NamidaFileExtensionsWrapper._({'csv', 'CSV'});
  static const json = NamidaFileExtensionsWrapper._({'json', 'JSON'});
  static const zip = NamidaFileExtensionsWrapper._({'zip', 'ZIP', 'rar', 'RAR'});
  static const compressed = NamidaFileExtensionsWrapper._({'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'cab', 'iso', 'jar'});
  static const lrcOrTxt = NamidaFileExtensionsWrapper._({'lrc', 'LRC', 'txt', 'TXT'});
}

const kDefaultOrientations = DeviceOrientation.values;

const kDefaultLang = NamidaLanguage(
  code: "en_US",
  name: "English",
  country: "United States",
);

const kDummyTrack = Track.explicit('');
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
  durationMS: 0,
  year: 0,
  yearText: '',
  size: 0,
  dateAdded: 0,
  dateModified: 0,
  path: "",
  comment: "",
  description: "",
  synopsis: "",
  bitrate: 0,
  sampleRate: 0,
  format: "",
  channels: "",
  discNo: 0,
  language: "",
  lyrics: "",
  label: "",
  rating: 0.0,
  originalTags: null,
  tagsList: [],
  gainData: null,
  albumIdentifierWrapper: null,
  isVideo: false,
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

const kThemeAnimationDurationMS = 250;

const kMaximumSleepTimerTracks = 40;
const kMaximumSleepTimerMins = 180;

extension PathTypeUtils on String {
  bool isVideo() => NamidaFileExtensionsWrapper.video.isPathValid(this);
}

class NamidaFeaturesVisibility {
  static final _platform = defaultTargetPlatform;
  static final _isAndroid = _platform == TargetPlatform.android;
  static final _isWindows = _platform == TargetPlatform.windows;

  static final wallpaperColors = _isAndroid && NamidaDeviceInfo.sdkVersion >= 31;
  static final displayArtworkOnLockscreen = _isAndroid && NamidaDeviceInfo.sdkVersion < 33;
  static final displayFavButtonInNotif = _isAndroid;
  static final displayFavButtonInNotifMightCauseIssue = displayFavButtonInNotif && NamidaDeviceInfo.sdkVersion < 31;
  static final shouldRequestManageAllFilesPermission = _isAndroid && NamidaDeviceInfo.sdkVersion >= 30;
  static final showEqualizerBands = _isAndroid;
  static final showToggleMediaStore = _isAndroid;
  static final showToggleImmersiveMode = _isAndroid;
  static final showRotateScreenInFullScreen = _isAndroid;

  static final methodSetCanEnterPip = _isAndroid;
  static final methodGetPlatformSdk = _isAndroid;
  static final methodSetMusicAs = _isAndroid;
  static final methodOpenSystemEqualizer = _isAndroid;

  static final onAudioQueryAvailable = _isAndroid;
  static final recieveSharingIntents = _isAndroid;
  static final changeApplicationBrightness = _isAndroid;

  static final showDownloadNotifications = _isWindows;
  static final showVideoControlsOnHover = _isWindows;
}
