// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:on_audio_edit/on_audio_edit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

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
    k_PLAYLIST_DIR_PATH_HISTORY,
  ]);

  final paths = await ExternalPath.getExternalStorageDirectories();
  kStoragePaths.assignAll(paths);
  kDirectoriesPaths.assignAll(paths.mappedUniqued((path) => "$path/${ExternalPath.DIRECTORY_MUSIC}"));
  kDirectoriesPaths.add('${paths[0]}/Download/');
  k_DIR_APP_INTERNAL_STORAGE = "${paths[0]}/Namida";

  await SettingsController.inst.prepareSettingsFile();
  await Indexer.inst.prepareTracksFile();

  /// updates values on startup
  Indexer.inst.updateImageSizeInStorage();
  Indexer.inst.updateWaveformSizeInStorage();
  Indexer.inst.updateColorPalettesSizeInStorage();
  Indexer.inst.updateVideosSizeInStorage();

  VideoController.inst.initialize();

  FlutterNativeSplash.remove();

  await PlaylistController.inst.prepareDefaultPlaylistsFile();

  PlaylistController.inst.prepareAllPlaylistsFile();
  QueueController.inst.prepareAllQueuesFile();

  await Player.inst.initializePlayer();
  await QueueController.inst.prepareLatestQueue();
  CurrentColor.inst.prepareColors();

  /// Clearing files cached by intents
  _clearIntentCachedFiles();

  void showErrorPlayingFileSnackbar({String? error}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final errorMessage = error != null ? '($error)' : '';
      Get.snackbar(Language.inst.ERROR, '${Language.inst.COULDNT_PLAY_FILE} $errorMessage');
    });
  }

  /// Recieving Initial Android Shared Intent.
  final intentfiles = await ReceiveSharingIntent.getInitialMedia();
  if (intentfiles.isNotEmpty) {
    final playedsuccessfully = await playExternalFiles(intentfiles.mapped((e) => e.path));
    if (!playedsuccessfully) {
      showErrorPlayingFileSnackbar();
    }
  }

  /// Listening to Android Shared Intents.
  /// Opening multiple files sometimes crashes the app.
  ReceiveSharingIntent.getMediaStream().listen(
    (event) async => await playExternalFiles(event.mapped((e) => e.path)),
    onError: (err) => showErrorPlayingFileSnackbar(error: err.toString()),
  );

  /// should be removed soon when fullscreen video is available.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  ScrollSearchController.inst.initialize();
  FlutterLocalNotificationsPlugin().cancelAll();
  runApp(const Namida());
  Folders.inst.onFirstLoad();
}

Future<void> _clearIntentCachedFiles() async {
  final cacheDir = await getTemporaryDirectory();
  await for (final cf in cacheDir.list()) {
    if (cf is File) {
      cf.tryDeleting();
    }
  }
}

/// returns [true] if played successfully.
Future<bool> playExternalFiles(Iterable<String> paths) async {
  final trs = await Indexer.inst.convertPathToTrack(paths);
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
    printo('Reset SAF Successully');
  } else {
    printo('Reset SAF Failure', isError: true);
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

class ScrollBehaviorModified extends ScrollBehavior {
  const ScrollBehaviorModified();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.android:
        return const BouncingScrollPhysics();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics();
    }
  }
}
