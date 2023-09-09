// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:catcher/catcher.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:picture_in_picture/picture_in_picture.dart';

import 'package:namida/controller/connectivity.dart';
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
import 'package:namida/core/translations/language.dart';
import 'package:namida/main_page_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Paint.enableDithering = true; // for smooth gradient effect.

  /// Getting Device info
  kSdkVersion = await PictureInPicture.getPlatformSdk();

  /// Granting Storage Permission.
  /// Requesting Granular media permissions for Android 13 (API 33) doesnt work for some reason.
  /// Currently the target API is set to 32.
  if (await Permission.storage.isDenied || await Permission.storage.isPermanentlyDenied) {
    final st = await Permission.storage.request();
    if (!st.isGranted) {
      SystemNavigator.pop();
    }
  }

  AppDirs.USER_DATA = await getExternalStorageDirectory().then((value) async => value?.path ?? await getApplicationDocumentsDirectory().then((value) => value.path));
  AppDirs.APP_CACHE = await getExternalCacheDirectories().then((value) async => value?.firstOrNull?.path ?? '');

  Future<void> createDirectories(List<String> paths) async {
    paths.loop((p, i) async {
      await Directory(p).create(recursive: true);
    });
  }

  await createDirectories(AppDirs.values);

  final paths = await ExternalPath.getExternalStorageDirectories();
  kStoragePaths.assignAll(paths);
  kDirectoriesPaths.assignAll(paths.mappedUniqued((path) => "$path/${ExternalPath.DIRECTORY_MUSIC}"));
  kDirectoriesPaths.add('${paths[0]}/Download/');
  AppDirs.INTERNAL_STORAGE = "${paths[0]}/Namida";

  await SettingsController.inst.prepareSettingsFile();
  await Future.wait([
    Indexer.inst.prepareTracksFile(),
    Language.initialize(),
  ]);
  ConnectivityController.inst.initialize();

  /// updates values on startup
  Indexer.inst.updateImageSizeInStorage();
  Indexer.inst.updateColorPalettesSizeInStorage();
  Indexer.inst.updateVideosSizeInStorage();

  FlutterNativeSplash.remove();

  QueueController.inst.prepareAllQueuesFile();

  await Player.inst.initializePlayer();
  PlaylistController.inst.prepareAllPlaylistsFile();
  VideoController.inst.initialize();
  await PlaylistController.inst.prepareDefaultPlaylistsFile();
  await QueueController.inst.prepareLatestQueue();

  await _initializeIntenties();

  await SystemChrome.setPreferredOrientations(kDefaultOrientations);

  ScrollSearchController.inst.initialize();
  FlutterLocalNotificationsPlugin().cancelAll();

  _initializeCatcher(() => runApp(const Namida()));

  CurrentColor.inst.generateAllColorPalettes();
  Folders.inst.onFirstLoad();
}

void _initializeCatcher(void Function() runAppFunction) {
  final options = CatcherOptions(SilentReportMode(), [FileHandler(File(AppPaths.LOGS), printLogs: true)]);

  Catcher(
    runAppFunction: runAppFunction,
    debugConfig: options,
    releaseConfig: options,
  );
}

Future<void> _initializeIntenties() async {
  Future<void> clearIntentCachedFiles() async {
    final cacheDir = await getTemporaryDirectory();
    await for (final cf in cacheDir.list()) {
      if (cf is File) {
        cf.tryDeleting();
      }
    }
  }

  /// Clearing files cached by intents
  clearIntentCachedFiles();

  void showErrorPlayingFileSnackbar({String? error}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final errorMessage = error != null ? '($error)' : '';
      Get.snackbar(lang.ERROR, '${lang.COULDNT_PLAY_FILE} $errorMessage');
    });
  }

  Future<void> playFiles(List<SharedFile> files) async {
    if (files.isNotEmpty) {
      final paths = files.map((e) => e.realPath?.replaceAll('\\', '') ?? e.value).whereType<String>();
      (await playExternalFiles(paths)).executeIfFalse(showErrorPlayingFileSnackbar);
    }
  }

  // -- Recieving Initial Android Shared Intent.
  await playFiles(await FlutterSharingIntent.instance.getInitialSharing());

  // -- Listening to Android Shared Intents.
  FlutterSharingIntent.instance.getMediaStream().listen(
        playFiles,
        onError: (err) => showErrorPlayingFileSnackbar(error: err.toString()),
      );
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
  Future<void> createDir() async => await Directory(SettingsController.inst.defaultBackupLocation.value).create(recursive: true);
  if (kSdkVersion < 30) {
    await createDir();
    return true;
  }

  if (!await Permission.manageExternalStorage.isGranted) {
    await Permission.manageExternalStorage.request();
  }

  if (!await Permission.manageExternalStorage.isGranted || await Permission.manageExternalStorage.isDenied) {
    Get.snackbar(lang.STORAGE_PERMISSION_DENIED, lang.STORAGE_PERMISSION_DENIED_SUBTITLE);
    return false;
  }
  await createDir();
  return true;
}

class Namida extends StatelessWidget {
  const Namida({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final locale = SettingsController.inst.selectedLanguage.value.code.split('_');
        return GetMaterialApp(
          key: Key(locale.join()),
          themeAnimationDuration: const Duration(milliseconds: kThemeAnimationDurationMS),
          debugShowCheckedModeBanner: false,
          title: 'Namida',
          restorationScopeId: 'Namida',
          theme: AppThemes.inst.getAppTheme(CurrentColor.inst.currentColorScheme, true),
          darkTheme: AppThemes.inst.getAppTheme(CurrentColor.inst.currentColorScheme, false),
          themeMode: SettingsController.inst.themeMode.value,
          builder: (context, widget) {
            return ScrollConfiguration(behavior: const ScrollBehaviorModified(), child: widget!);
          },
          home: const MainPageWrapper(),
        );
      },
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
