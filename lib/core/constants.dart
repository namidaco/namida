// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:intl/intl.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/version_wrapper.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/base.dart';
import 'package:namida/controller/platform/zip_manager/zip_manager.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';

final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

class NamidaDeviceInfo {
  static int sdkVersion = -1;

  static String? _deviceId;

  static final deviceInfoCompleter = Completer<BaseDeviceInfo?>();
  static final packageInfoCompleter = Completer<PackageInfo?>();

  static BaseDeviceInfo? deviceInfo;
  static PackageInfo? packageInfo;

  static VersionWrapper? version;
  static String? buildType;

  static bool _fetchedDeviceInfo = false;
  static bool _fetchedPackageInfo = false;

  static Future<void> fetchDeviceInfo() async {
    if (_fetchedDeviceInfo) return;
    _fetchedDeviceInfo = true;
    try {
      final res = await DeviceInfoPlugin().deviceInfo;
      deviceInfo = res;
    } catch (_) {
      _fetchedDeviceInfo = false;
    } finally {
      deviceInfoCompleter.complete(deviceInfo);
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
    } catch (_) {
      _fetchedPackageInfo = false;
    } finally {
      packageInfoCompleter.complete(packageInfo);
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
    r'\b(?:https?://)?(?:www\.)?(?:youtube\.com/(?:watch\?v=|embed/|v/|shorts/)|youtu\.be/)([\w\-]{11})(?:\S+)?',
    caseSensitive: false,
  );

  static final youtubeIdRegex = RegExp(
    r'(?:youtube\.com/(?:watch\?v=|embed/|v/|shorts/)|youtu\.be/)([\w\-]{11})',
    caseSensitive: false,
  );

  static final youtubePlaylistsLinkRegex = RegExp(
    r'\b(?:https?://)?(?:www\.)?(?:youtube\.com/playlist\?list=)([\w\-]+)(?:\S+)?',
    caseSensitive: false,
  );
}

class NamidaUtils {
  NamidaUtils._();

  static Future<void> shareFiles(Iterable<String> paths) async {
    await Share.shareXFiles(paths.map((e) => XFile(e)).toList());
  }

  static Future<void> shareUri(String url) async {
    if (Platform.isWindows) {
      await shareText(url);
    } else {
      await Share.shareUri(Uri.parse(url));
    }
  }

  static Future<void> shareText(String text) async {
    await Share.share(text);
  }

  static void copyToClipboard({
    String? title,
    required String content,
    String? message,
    Color? leftBarIndicatorColor,
    int? maxLinesMessage,
    bool altDesign = false,
  }) {
    if (content == '' || content == '?') return;

    Clipboard.setData(ClipboardData(text: content));

    snackyy(
      title: title == null || title.isEmpty ? lang.COPIED_TO_CLIPBOARD : '${lang.COPIED_TO_CLIPBOARD}: $title',
      message: message ?? content,
      leftBarIndicatorColor: leftBarIndicatorColor ?? CurrentColor.inst.color,
      maxLinesMessage: maxLinesMessage,
      altDesign: altDesign,
      top: false,
    );
  }
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

  static Future<bool> openLink(String url, {LaunchMode preferredMode = LaunchMode.externalNonBrowserApplication}) async {
    bool didLaunch = false;
    try {
      didLaunch = await launchUrlString(url, mode: preferredMode);
    } catch (_) {}
    if (!didLaunch) {
      try {
        didLaunch = await launchUrlString(url);
      } catch (_) {}
    }
    return didLaunch;
  }

  static Future<bool> openLinkPreferNamida(String url, {ThemeData? theme}) {
    final didOpen = tryOpeningPlaylistOrVideo(url, theme: theme);
    if (didOpen) return Future.value(true);
    return openLink(url);
  }

  static bool tryOpeningPlaylistOrVideo(String url, {ThemeData? theme}) {
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
      OnYoutubeLinkOpenAction.alwaysAsk.execute([possibleVideoId], theme: theme);
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
      final possibleId = NamidaLinkRegex.youtubeIdRegex.firstMatch(link)?.group(1);
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
  SETTINGS_SHORTCUTS,
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
  PLAYLISTS_METADATA(true),
  QUEUES(true),
  ARTWORKS(true),
  ARTWORKS_ARTISTS(true),
  ARTWORKS_ALBUMS(true),
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
  YT_PLAYLISTS_METADATA(true),
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
      AppPathsBackupEnum.SETTINGS_SHORTCUTS => AppPaths.SETTINGS_SHORTCUTS,
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
      AppPathsBackupEnum.PLAYLISTS_METADATA => AppDirs.PLAYLISTS_METADATA,
      AppPathsBackupEnum.QUEUES => AppDirs.QUEUES,
      AppPathsBackupEnum.ARTWORKS => AppDirs.ARTWORKS,
      AppPathsBackupEnum.ARTWORKS_ARTISTS => AppDirs.ARTWORKS_ARTISTS,
      AppPathsBackupEnum.ARTWORKS_ALBUMS => AppDirs.ARTWORKS_ALBUMS,
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
      AppPathsBackupEnum.YT_PLAYLISTS_METADATA => AppDirs.YT_PLAYLISTS_METADATA,
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

  static final everything = [
    ...AppPathsBackupEnumCategories.database,
    ...AppPathsBackupEnumCategories.database_yt,
    ...AppPathsBackupEnumCategories.settings,
    ...AppPathsBackupEnumCategories.history,
    ...AppPathsBackupEnumCategories.history_yt,
    ...AppPathsBackupEnumCategories.playlists,
    ...AppPathsBackupEnumCategories.playlists_yt,
    ...AppPathsBackupEnumCategories.queues,
    ...AppPathsBackupEnumCategories.lyrics,
    ...AppPathsBackupEnumCategories.palette,
    ...AppPathsBackupEnumCategories.palette_yt,
  ];

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
    AppPathsBackupEnum.PLAYLISTS_METADATA,
    AppPathsBackupEnum.FAVOURITES_PLAYLIST,
  ];
  static List<AppPathsBackupEnum> playlists_yt = [
    AppPathsBackupEnum.YT_PLAYLISTS,
    AppPathsBackupEnum.YT_PLAYLISTS_ARTWORKS,
    AppPathsBackupEnum.YT_PLAYLISTS_METADATA,
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
    AppPathsBackupEnum.SETTINGS_SHORTCUTS,
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
    AppPathsBackupEnum.ARTWORKS_ARTISTS,
    AppPathsBackupEnum.ARTWORKS_ALBUMS,
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
  static final SETTINGS_SHORTCUTS = _join(_USER_DATA, 'namida_settings_shortcuts.json');
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

  static Future<List<String>> getAllExistingLogsAndSettingsAsZip() async {
    final format = DateFormat('yyyy-MM-dd HH.mm.ss');
    final dateText = format.format(DateTime.now());
    final tmpDirParentPath = FileParts.joinPath((await pp.getTemporaryDirectory()).path, 'namida_logs_$dateText');
    final tmpDirContentsPath = FileParts.joinPath(tmpDirParentPath, 'contents');
    final tmpDirContents = await Directory(tmpDirContentsPath).create(recursive: true);
    await _copyAllExistingLogAndSettingsTo(tmpDirPath: tmpDirContentsPath);
    final zipper = ZipManager.platform();
    final zipFile = FileParts.join(tmpDirParentPath, 'namida_logs_$dateText.zip');
    await zipper.createZipFromDirectory(
      sourceDir: tmpDirContents,
      zipFile: zipFile,
    );
    tmpDirContents.delete(recursive: true);
    return [zipFile.path];
  }

  static Future<List<File>> _copyAllExistingLogAndSettingsTo({required String tmpDirPath, bool includeSettings = true}) async {
    final existingPaths = <File>[];
    final deviceInfoFile = FileParts.join(tmpDirPath, 'device_info.txt');
    try {
      final deviceInfo = await _getDeviceInfo();
      await deviceInfoFile.create(recursive: true);
      await deviceInfoFile.writeAsString(deviceInfo);
      existingPaths.add(deviceInfoFile);
    } catch (_) {}
    for (final p in [
      AppPaths.LOGS,
      AppPaths.LOGS_FALLBACK,
      AppPaths.LOGS_TAGGER,
      if (includeSettings) ...[
        AppPaths.SETTINGS,
        AppPaths.SETTINGS_EQUALIZER,
        AppPaths.SETTINGS_PLAYER,
        AppPaths.SETTINGS_YOUTUBE,
        AppPaths.SETTINGS_EXTRA,
        AppPaths.SETTINGS_TUTORIAL,
        AppPaths.SETTINGS_SHORTCUTS,
      ],
    ]) {
      final file = File(p);
      if (await file.exists()) {
        final copy = await file.copy(FileParts.joinPath(tmpDirPath, p.getFilename));
        final size = await copy.fileSize();
        if (size != null && size > 0) {
          existingPaths.add(copy);
        }
      }
    }
    return existingPaths;
  }

  static String get LOGS_FALLBACK => _getFallbackLogsFilePath();
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

  static String _getFallbackLogsFilePath() {
    return NamidaPlatformBuilder.init(
      android: () => '/storage/emulated/0/Documents/namida_logs.txt',
      windows: () {
        final home = NamidaPlatformBuilder.windowsNamidaHome;
        if (home != null && home.isNotEmpty) return FileParts.joinPath(home, 'Logs', 'namida_logs.txt');
        return FileParts.joinPath(Directory.systemTemp.path, 'namida_logs.txt');
      },
      linux: () {
        final home = NamidaPlatformBuilder.linuxNamidaHome;
        if (home != null && home.isNotEmpty) return FileParts.joinPath(home, 'Logs', 'namida_logs.txt');
        return FileParts.joinPath(Directory.systemTemp.path, 'namida_logs.txt');
      },
    );
  }

  static Future<String> _getDeviceInfo() async {
    final device = await NamidaDeviceInfo.deviceInfoCompleter.future;
    final package = await NamidaDeviceInfo.packageInfoCompleter.future;
    final deviceMap = device?.data;
    final packageMap = package?.data;

    // -- android
    deviceMap?.remove('supported32BitAbis');
    deviceMap?.remove('supported64BitAbis');
    deviceMap?.remove('systemFeatures');
    // -----------

    // -- windows
    deviceMap?.remove('digitalProductId');
    // -----------

    final encoder = JsonEncoder.withIndent(
      "  ",
      (object) {
        if (object is DateTime) {
          return object.toString();
        }
        try {
          return object.toJson();
        } catch (_) {
          return object.toString();
        }
      },
    );
    final infoMap = {
      'device': deviceMap,
      'package': packageMap,
    };
    return encoder.convert(infoMap);
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
  static final PLAYLISTS_METADATA = _join(USER_DATA, 'Playlists Metadata');
  static final QUEUES = _join(USER_DATA, 'Queues');
  static final ARTWORKS = _join(USER_DATA, 'Artworks'); // extracted audio artworks
  static final ARTWORKS_ARTISTS = _join(USER_DATA, 'Artworks Artists');
  static final ARTWORKS_ALBUMS = _join(USER_DATA, 'Artworks Albums');
  static final PALETTES = _join(USER_DATA, 'Palettes');
  static final VIDEOS_CACHE = _join(USER_DATA, 'Videos');
  static final AUDIOS_CACHE = _join(USER_DATA, 'Audios');
  static final VIDEOS_CACHE_TEMP = _join(USER_DATA, 'Videos', 'Temp');
  static final THUMBNAILS = _join(USER_DATA, 'Thumbnails'); // extracted video thumbnails
  static final LYRICS = _join(USER_DATA, 'Lyrics');
  static final M3UBackup = _join(USER_DATA, 'M3U Backup'); // backups m3u on first found
  static final RECENTLY_DELETED = _join(USER_DATA, 'Recently Deleted'); // stores files that was deleted recently
  static String get LOGS_DIRECTORY => _join(USER_DATA, 'Logs');

  static final LOGIN = _join(ROOT_DIR, 'login'); // this should never be accessed/backed up etc.

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
  static final YT_PLAYLISTS_METADATA = _join(YOUTUBE_MAIN_DIRECTORY, 'Youtube Playlists Metadata');
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
    ARTWORKS_ARTISTS,
    ARTWORKS_ALBUMS,
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

  static const NAMIDA_SYNC_GITHUB_RELEASE = 'https://github.com/010101-sans/namida_sync/releases';
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
    return extensions.contains(ext.toLowerCase());
  }

  static const _audioExtensions = {
    'm4a', 'mp3', 'wav', 'flac', 'ogg', 'oga', 'ogx', 'aac', 'opus', 'weba', 'm4b', 'alac', 'ac3', 'mp2', 'm4p', 'mpa', //
    'amr', 'ape', 'aa', 'aax', 'act', 'dss', 'dts', 'dvf', 'dct', 'dff', 'dsf', 'mmf', 'mid', 'mpc', 'msv', 'mogg',
    'raw', 'ra', 'voc', 'wma', 'caf', 'aiff', 'wv', 'aif', 'aifc', 'm4r', 'mac', 'mka', 'mlp', 'mpp', 'uax',
  };

  static const _videoExtensions = {
    'mp4', 'mkv', 'avi', 'wmv', 'flv', 'mov', '3gp', 'ogv', 'webm', 'mpg', 'mpeg', 'm4v', 'ts', 'vob', 'asf', //
    'rm', 'f4v', 'divx', 'm2ts', 'mts', 'mpv', 'mpe', 'mxf', 'm2v', 'mpeg1', 'mpeg2', 'mpeg4',
  };

  static const _zipExtensions = {
    'zip', 'rar', '7z', //
  };

  static const audio = NamidaFileExtensionsWrapper._(_audioExtensions);
  static const video = NamidaFileExtensionsWrapper._(_videoExtensions);
  static const audioAndVideo = NamidaFileExtensionsWrapper._({..._audioExtensions, ..._videoExtensions});

  static const image = NamidaFileExtensionsWrapper._({
    'png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp', //
  });

  static const m3u = NamidaFileExtensionsWrapper._({'m3u', 'm3u8'});
  static const csv = NamidaFileExtensionsWrapper._({'csv'});
  static const json = NamidaFileExtensionsWrapper._({'json'});
  static const zip = NamidaFileExtensionsWrapper._(_zipExtensions);
  static const jsonAndZip = NamidaFileExtensionsWrapper._({'json', ..._zipExtensions});
  static const compressed = NamidaFileExtensionsWrapper._({..._zipExtensions, 'tar', 'gz', 'bz2', 'xz', 'cab', 'iso', 'jar'});
  static const lrcOrTxt = NamidaFileExtensionsWrapper._({'lrc', 'xml', 'ttml', 'txt'});

  static const exe = NamidaFileExtensionsWrapper._({'exe'});
}

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
  hashKey: null,
  gainData: null,
  albumIdentifierWrapper: null,
  isVideo: false,
  server: null,
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

abstract class NamidaFeaturesAvailablityBase {
  const NamidaFeaturesAvailablityBase();

  bool resolve();
  String get text;
}

class NamidaFeaturesAvailablityGroup extends NamidaFeaturesAvailablityBase {
  final List<NamidaFeaturesAvailablity> items;

  const NamidaFeaturesAvailablityGroup({required this.items});

  @override
  String get text => items.join(' | ');

  @override
  bool resolve() {
    return items.any((element) => element.resolve());
  }
}

enum NamidaFeaturesAvailablity implements NamidaFeaturesAvailablityBase {
  android('Android'),
  windows('Windows'),
  linux('Linux'),
  android13and_plus('Android 13+'), // >= 33
  android12and_plus('Android S/12+'), // >= 31
  android12and_below('Android <= 12'), // <= 32
  android11and_plus('Android 11+'), // >=30
  android11and_below('Android <= 11'), // <=30
  ;

  @override
  final String text;
  const NamidaFeaturesAvailablity(this.text);

  @override
  bool resolve() {
    final isAndroid = NamidaFeaturesVisibility._isAndroid;
    return switch (this) {
      NamidaFeaturesAvailablity.android => isAndroid,
      NamidaFeaturesAvailablity.windows => NamidaFeaturesVisibility._isWindows,
      NamidaFeaturesAvailablity.linux => NamidaFeaturesVisibility._isLinux,
      NamidaFeaturesAvailablity.android13and_plus => isAndroid && NamidaDeviceInfo.sdkVersion >= 33,
      NamidaFeaturesAvailablity.android12and_plus => isAndroid && NamidaDeviceInfo.sdkVersion >= 31,
      NamidaFeaturesAvailablity.android12and_below => isAndroid && NamidaDeviceInfo.sdkVersion <= 32,
      NamidaFeaturesAvailablity.android11and_plus => isAndroid && NamidaDeviceInfo.sdkVersion >= 30,
      NamidaFeaturesAvailablity.android11and_below => isAndroid && NamidaDeviceInfo.sdkVersion <= 30,
    };
  }
}

class NamidaFeaturesVisibility {
  static final _platform = defaultTargetPlatform;
  static final _isAndroid = _platform == TargetPlatform.android;
  static final _isWindows = _platform == TargetPlatform.windows;
  static final _isLinux = _platform == TargetPlatform.linux;

  static final wallpaperColors = NamidaFeaturesAvailablity.android12and_plus.resolve();
  static final displayArtworkOnLockscreen = NamidaFeaturesAvailablity.android12and_below.resolve();
  static final displayFavButtonInNotif = _isAndroid;
  static final displayFavButtonInNotifMightCauseIssue = displayFavButtonInNotif && NamidaFeaturesAvailablity.android11and_below.resolve();
  static final displayStopButtonInNotif = _isAndroid;
  static final displayAppIcons = _isAndroid;
  static final showEqualizerBands = _isAndroid;
  static final showToggleMediaStore = onAudioQueryAvailable;
  static final showToggleImmersiveMode = _isAndroid;
  static final showRotateScreenInFullScreen = _isAndroid;
  static final floatingArtworkEffect = _isAndroid;
  static final mediaWaveHaptic = _isAndroid;

  static final methodSetCanEnterPip = _isAndroid;
  static final methodSetMusicAs = _isAndroid;
  static final methodOpenSystemEqualizer = _isAndroid;
  static final methodOnNotificationTapAction = _isAndroid;

  static final onAudioQueryAvailable = _isAndroid;
  static final recieveSharingIntents = _isAndroid;
  static final changeApplicationBrightness = _isAndroid;
  static final equalizerAvailable = _isAndroid;
  static final loudnessEnhancerAvailable = _isAndroid;
  static final gaplessPlaybackAvailable = _isAndroid;

  static final showDownloadNotifications = _isWindows || _isLinux;
  static final showVideoControlsOnHover = _isWindows || _isLinux;
  static final tiltingCardsEffect = _isWindows || _isLinux;
  static final smoothScrolling = _isWindows || _isLinux;

  static final isStoragePermissionNotRequired = _isWindows || _isLinux;
  static final recieveDragAndDrop = _isWindows || _isLinux;
}
