// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:on_audio_edit/on_audio_edit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/core/translations/translations.dart';

import 'package:namida/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Paint.enableDithering = true; // for smooth gradient effect.

  /// Getting Device info
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  kSdkVersion = androidInfo.version.sdkInt;

  /// Granting Storage Permission.
  /// Requesting Granular media permissions for Android 13 (API 33) doesnt work for some reason.
  /// Currently the target API is set to 32.
  if (await Permission.storage.isDenied || await Permission.storage.isPermanentlyDenied) {
    final st = await Permission.storage.request();
    if (!st.isGranted) {
      SystemNavigator.pop();
    }
  }

  k_DIR_USER_DATA = await getExternalStorageDirectory().then((value) async => value?.path ?? await getApplicationDocumentsDirectory().then((value) => value.path));

  Future<void> createDirectories(List<String> paths) async {
    paths.loop((p, i) async {
      await Directory(p).create(recursive: true);
    });
  }

  await createDirectories([
    k_DIR_ARTWORKS,
    k_DIR_PALETTES,
    k_DIR_WAVEFORMS,
    k_DIR_VIDEOS_CACHE,
    k_DIR_VIDEOS_CACHE_TEMP,
    k_DIR_LYRICS,
    k_DIR_YT_METADATA,
    k_DIR_YT_METADATA_COMMENTS,
    k_DIR_PLAYLISTS,
    k_DIR_QUEUES,
    k_DIR_YOUTUBE_STATS,
  ]);

  final paths = await ExternalPath.getExternalStorageDirectories();
  kStoragePaths.assignAll(paths);
  kDirectoriesPaths.assignAll(paths.map((path) => "$path/${ExternalPath.DIRECTORY_MUSIC}").toSet());
  kDirectoriesPaths.add('${paths[0]}/Download/');
  k_DIR_APP_INTERNAL_STORAGE = "${paths[0]}/Namida";

  VideoController.inst.initialize();

  await SettingsController.inst.prepareSettingsFile();
  await Indexer.inst.prepareTracksFile();

  /// updates values on startup
  Indexer.inst.updateImageSizeInStorage();
  Indexer.inst.updateWaveformSizeInStorage();
  Indexer.inst.updateColorPalettesSizeInStorage();
  Indexer.inst.updateVideosSizeInStorage();

  VideoController.inst.getVideoFiles();

  FlutterNativeSplash.remove();

  // playlists should be prepared first since it can used as reference in queues.
  await PlaylistController.inst.prepareDefaultPlaylistsFile();

  PlaylistController.inst.prepareAllPlaylistsFile();
  QueueController.inst.prepareAllQueuesFile();

  await QueueController.inst.prepareLatestQueueFile();
  await Player.inst.initializePlayer();
  await QueueController.inst.putLatestQueue();
  await Player.inst.prepareTotalListenTime();
  await CurrentColor.inst.prepareColors();

  /// Clearing files cached by intents
  final cacheDirFiles = await getTemporaryDirectory().then((value) => value.listSync());
  for (final cf in cacheDirFiles) {
    if (cf is File) {
      cf.deleteSync();
    }
  }
  void shouldErrorPlayingFileSnackbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.snackbar(Language.inst.ERROR, Language.inst.COULDNT_PLAY_FILE);
    });
  }

  /// Recieving Initial Android Shared Intent.
  final intentfiles = await ReceiveSharingIntent.getInitialMedia();
  if (intentfiles.isNotEmpty) {
    final playedsuccessfully = await playExternalFiles(intentfiles.map((e) => e.path).toList());
    if (!playedsuccessfully) {
      shouldErrorPlayingFileSnackbar();
    }
  }

  /// Listening to Android Shared Intents.
  /// Opening multiple files sometimes crashes the app.
  ReceiveSharingIntent.getMediaStream().listen((event) async {
    await playExternalFiles(event.map((e) => e.path).toList());
  }, onError: (err) {
    shouldErrorPlayingFileSnackbar();
  });

  /// should be removed soon when fullscreen video is available.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  ScrollSearchController.inst.initialize();
  runApp(const Namida());
  Folders.inst.onFirstLoad();
}

/// returns [true] if played successfully.
Future<bool> playExternalFiles(List<String> paths) async {
  final List<Track> trs = [];
  for (final p in paths) {
    final tr = await Indexer.inst.convertPathToTrack(p);
    if (tr != null) {
      trs.add(tr);
    }
  }
  if (trs.isNotEmpty) {
    await Player.inst.playOrPause(0, trs, QueueSource.externalFile);
    return true;
  }
  return false;
}

Future<bool> requestManageStoragePermission() async {
  if (kSdkVersion < 30) {
    return true;
  }

  if (!await Permission.manageExternalStorage.isGranted) {
    await Permission.manageExternalStorage.request();
  }

  if (!await Permission.manageExternalStorage.isGranted || await Permission.manageExternalStorage.isDenied) {
    Get.snackbar(Language.inst.STORAGE_PERMISSION_DENIED, Language.inst.STORAGE_PERMISSION_DENIED_SUBTITLE);
    return false;
  }
  return true;
}

Future<void> resetSAFPermision() async {
  if (kSdkVersion < 30) {
    return;
  }
  final didReset = await OnAudioEdit().resetComplexPermission();
  if (didReset) {
    Get.snackbar(Language.inst.PERMISSION_UPDATE, Language.inst.RESET_SAF_PERMISSION_RESET_SUCCESS);
    debugPrint('Reset SAF Successully');
  } else {
    debugPrint('Reset SAF Failure');
  }
}

class Namida extends StatelessWidget {
  const Namida({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Namida',
      theme: AppThemes.inst.getAppTheme(CurrentColor.inst.currentColorScheme.value, true),
      darkTheme: AppThemes.inst.getAppTheme(CurrentColor.inst.currentColorScheme.value, false),
      themeMode: SettingsController.inst.themeMode.value,
      translations: MyTranslation(),
      builder: (context, widget) {
        return ScrollConfiguration(behavior: const ScrollBehaviorModified(), child: widget!);
      },
      home: const MainPageWrapper(),
    );
  }
}
