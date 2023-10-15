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

import 'package:namida/controller/clipboard_controller.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main_page_wrapper.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Paint.enableDithering = true; // for smooth gradient effect.

  /// Getting Device info
  kSdkVersion = await PictureInPicture.getPlatformSdk();

  /// if `true`:
  /// 1. onboarding screen will show
  /// 2. `indexer` and `latest queue` will be executed after permission is granted.
  bool shouldShowOnBoarding = false;

  if (!await requestStoragePermission(request: false)) {
    shouldShowOnBoarding = true;
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

  AppDirs.INTERNAL_STORAGE = "${paths[0]}/Namida";
  final downloadsFolder = "${paths[0]}/Download/";

  kDirectoriesPaths.addAll([downloadsFolder, AppDirs.INTERNAL_STORAGE]);

  await settings.prepareSettingsFile();
  await Future.wait([
    if (!shouldShowOnBoarding) Indexer.inst.prepareTracksFile(),
    Language.initialize(),
  ]);
  ConnectivityController.inst.initialize();
  ClipboardController.inst.initialize();

  /// updates values on startup
  Indexer.inst.updateImageSizeInStorage();
  Indexer.inst.updateColorPalettesSizeInStorage();
  Indexer.inst.updateVideosSizeInStorage();

  FlutterNativeSplash.remove();

  QueueController.inst.prepareAllQueuesFile();

  await Player.inst.initializePlayer();
  PlaylistController.inst.prepareAllPlaylists();
  VideoController.inst.initialize();
  await PlaylistController.inst.prepareDefaultPlaylistsFile();
  if (!shouldShowOnBoarding) await QueueController.inst.prepareLatestQueue();

  YoutubePlaylistController.inst.prepareAllPlaylists();
  await YoutubePlaylistController.inst.prepareDefaultPlaylistsFile();
  YoutubeController.inst.fillBackupInfoMap(); // for history videos info.

  await _initializeIntenties();

  await Future.wait([
    SystemChrome.setPreferredOrientations(kDefaultOrientations),
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values),
  ]);

  ScrollSearchController.inst.initialize();
  FlutterLocalNotificationsPlugin().cancelAll();

  // runApp(Namida(shouldShowOnBoarding: shouldShowOnBoarding));
  _initializeCatcher(() => runApp(Namida(shouldShowOnBoarding: shouldShowOnBoarding)));

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
      snackyy(title: lang.ERROR, message: '${lang.COULDNT_PLAY_FILE} $errorMessage');
    });
  }

  Future<void> playFiles(List<SharedFile> files) async {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (files.isNotEmpty) {
        final paths = files.map((e) => e.realPath?.replaceAll('\\', '') ?? e.value).whereType<String>();
        if (paths.isNotEmpty) {
          final youtubeIds = paths.map((e) {
            final id = e.getYoutubeID;
            return id == '' ? null : id;
          }).whereType<String>();
          if (youtubeIds.isNotEmpty) {
            await _waitForFirstBuildContext.future;
            settings.onYoutubeLinkOpen.value.execute(youtubeIds);
          } else {
            final existing = paths.where((element) => File(element).existsSync()); // this for sussy links
            final err = await playExternalFiles(existing);
            if (err != null) showErrorPlayingFileSnackbar(error: err);
          }
        }
      }
    });
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
Future<String?> playExternalFiles(Iterable<String> paths) async {
  try {
    final trs = await Indexer.inst.convertPathToTrack(paths);
    if (trs.isNotEmpty) {
      await Player.inst.playOrPause(0, trs, QueueSource.externalFile);
      return null;
    } else {
      return 'Empty List';
    }
  } catch (e) {
    return e.toString();
  }
}

/// Granting Storage Permission.
/// Requesting Granular media permissions for Android 13 (API 33) doesnt work for some reason.
/// Currently the target API is set to 32.
/// [request] will prompt dialog if not granted.
Future<bool> requestStoragePermission({bool request = true}) async {
  bool granted = false;
  if (await Permission.storage.isPermanentlyDenied) {
    if (request) {
      // -- user denied, should open settings.
      await openAppSettings();
    }
  } else if (await Permission.storage.isDenied) {
    if (request) {
      final st = await Permission.storage.request();
      if (st.isPermanentlyDenied) {
        await openAppSettings();
      }
      granted = st.isGranted;
    }
  } else {
    granted = true;
  }
  return granted;
}

Future<bool> requestManageStoragePermission() async {
  Future<void> createDir() async => await Directory(settings.defaultBackupLocation.value).create(recursive: true);
  if (kSdkVersion < 30) {
    await createDir();
    return true;
  }

  if (!await Permission.manageExternalStorage.isGranted) {
    await Permission.manageExternalStorage.request();
  }

  if (!await Permission.manageExternalStorage.isGranted || await Permission.manageExternalStorage.isDenied) {
    snackyy(title: lang.STORAGE_PERMISSION_DENIED, message: lang.STORAGE_PERMISSION_DENIED_SUBTITLE);
    return false;
  }
  await createDir();
  return true;
}

BuildContext get rootContext => _initialContext;
late BuildContext _initialContext;
final _waitForFirstBuildContext = Completer<bool>();

class Namida extends StatelessWidget {
  final bool shouldShowOnBoarding;
  const Namida({super.key, required this.shouldShowOnBoarding});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final locale = settings.selectedLanguage.value.code.split('_');
        return GetMaterialApp(
          key: Key(locale.join()),
          themeAnimationDuration: const Duration(milliseconds: kThemeAnimationDurationMS),
          debugShowCheckedModeBanner: false,
          title: 'Namida',
          // restorationScopeId: 'Namida',
          theme: AppThemes.inst.getAppTheme(CurrentColor.inst.currentColorScheme, true),
          darkTheme: AppThemes.inst.getAppTheme(CurrentColor.inst.currentColorScheme, false),
          themeMode: settings.themeMode.value,
          builder: (context, widget) {
            return ScrollConfiguration(behavior: const ScrollBehaviorModified(), child: widget!);
          },
          home: MainPageWrapper(
            shouldShowOnBoarding: shouldShowOnBoarding,
            onContextAvailable: (ctx) {
              _initialContext = ctx;
              _waitForFirstBuildContext.isCompleted ? null : _waitForFirstBuildContext.complete(true);
            },
          ),
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
