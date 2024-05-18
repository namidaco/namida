// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/namida_channel.dart';
import 'package:namida/controller/namida_channel_storage.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/storage_cache_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main_page_wrapper.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/video_widget.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

void main() {
  runZonedGuarded(
    mainInitialization,
    (error, stack) => logger.error(error.runtimeType, e: error, st: stack),
  );
}

void mainInitialization() async {
  WidgetsFlutterBinding.ensureInitialized();
  Paint.enableDithering = true; // for smooth gradient effect.

  // -- x this makes some issues with GestureDetector
  // GestureBinding.instance.resamplingEnabled = true; // for 120hz displays, should make scrolling smoother.

  /// Getting Device info
  NamidaDeviceInfo.fetchAndroidInfo();
  NamidaDeviceInfo.fetchPackageInfo().then((value) {
    // -- in case full path was updated before fetching version
    logger.updateLoggerPath();
    FAudioTaggerController.inst.updateLogsPath();
  });
  NamidaDeviceInfo.sdkVersion = await NamidaChannel.inst.getPlatformSdk();

  /// if `true`:
  /// 1. onboarding screen will show
  /// 2. `indexer` and `latest queue` will be executed after permission is granted.
  bool shouldShowOnBoarding = false;

  if (!await requestStoragePermission(request: false)) {
    shouldShowOnBoarding = true;
  }

  late final List<String> paths;
  Future<void> fetchAppData() async {
    final appDatas = await NamidaStorage.inst.getStorageDirectoriesAppData();
    AppDirs.USER_DATA = appDatas.firstOrNull ?? '';
    logger.updateLoggerPath();
    FAudioTaggerController.inst.updateLogsPath();
  }

  await Future.wait([
    fetchAppData(),
    NamidaStorage.inst.getStorageDirectories().then((value) => paths = value),
    NamidaStorage.inst.getStorageDirectoriesAppCache().then((value) => AppDirs.APP_CACHE = value.firstOrNull ?? ''),
  ]);
  _initErrorInterpreters();
  _cleanOldLogs.thready({'dirPath': AppDirs.LOGS_DIRECTORY, 'fileSuffix': AppPaths.getLogsSuffix()});

  if (paths.isEmpty) paths.add('/storage/emulated/0');

  // -- creating directories
  AppDirs.values.loop((p, _) => Directory(p).createSync(recursive: true));

  kStoragePaths.addAll(paths);

  AppDirs.INTERNAL_STORAGE = "${paths[0]}/Namida";
  final downloadsFolder = "${paths[0]}/Download/";

  kInitialDirectoriesToScan.addAll([
    ...paths.mappedUniqued((path) => "$path/Music"),
    downloadsFolder,
    AppDirs.INTERNAL_STORAGE,
  ]);

  await Future.wait([
    settings.equalizer.prepareSettingsFile(),
    settings.player.prepareSettingsFile(),
    settings.prepareSettingsFile(),
  ]);

  await Future.wait([
    if (!shouldShowOnBoarding) Indexer.inst.prepareTracksFile(),
    Language.initialize(),
  ]);
  ConnectivityController.inst.initialize();
  NamidaChannel.inst.setCanEnterPip(settings.enablePip.value);

  /// updates values on startup
  Indexer.inst.calculateAllImageSizesInStorage();
  Indexer.inst.updateColorPalettesSizeInStorage();
  Indexer.inst.updateVideosSizeInStorage();
  if (!shouldShowOnBoarding && settings.refreshOnStartup.value) {
    Indexer.inst.refreshLibraryAndCheckForDiff(allowDeletion: false, showFinishedSnackbar: false);
  }
  if (!shouldShowOnBoarding) {
    BackupController.inst.checkForAutoBackup();
  }

  const StorageCacheManager().trimExtraFiles();

  QueueController.inst.prepareAllQueuesFile();

  await Player.inst.initializePlayer();
  PlaylistController.inst.prepareAllPlaylists();
  VideoController.inst.initialize();

  FlutterNativeSplash.remove();

  HistoryController.inst.prepareHistoryFile().then((_) => Indexer.inst.sortMediaTracksSubListsAfterHistoryPrepared());
  YoutubeHistoryController.inst.prepareHistoryFile();
  await Future.wait([
    PlaylistController.inst.prepareDefaultPlaylistsFile(),
    if (!shouldShowOnBoarding) QueueController.inst.prepareLatestQueue(),
    YoutubePlaylistController.inst.prepareDefaultPlaylistsFile(),
    YoutubeController.inst.loadDownloadTasksInfoFile(),
    YoutubeSubscriptionsController.inst.loadSubscriptionsFile()
  ]);

  YoutubePlaylistController.inst.prepareAllPlaylists();

  YoutubeController.inst.loadInfoToMemory();
  YoutubeController.inst.fillBackupInfoMap(); // for history videos info.

  await _initializeIntenties();

  await Future.wait([
    SystemChrome.setPreferredOrientations(kDefaultOrientations),
    NamidaNavigator.inst.setDefaultSystemUI(),
    FlutterDisplayMode.setHighRefreshRate(),
  ]);

  NamidaNavigator.inst.setDefaultSystemUIOverlayStyle();

  ScrollSearchController.inst.initialize();
  FlutterLocalNotificationsPlugin().cancelAll();
  FlutterVolumeController.updateShowSystemUI(false);
  CurrentColor.inst.initialize();

  runApp(Namida(shouldShowOnBoarding: shouldShowOnBoarding));

  // CurrentColor.inst.generateAllColorPalettes();
  Folders.inst.onFirstLoad();

  _initLifeCycle();
}

void _cleanOldLogs(Map params) {
  final dirPath = params['dirPath'] as String;
  final fileSuffix = params['fileSuffix'] as String?;
  Directory(dirPath).listSync().loop((e, _) {
    if (e is File) {
      final filename = e.path.getFilename;
      if (filename.startsWith('logs_') && fileSuffix != null && !filename.endsWith("$fileSuffix.txt")) {
        try {
          e.deleteSync();
        } catch (_) {}
      }
    }
  });
}

void _initErrorInterpreters() {
  Isolate.current.addErrorListener(
    RawReceivePort((dynamic pair) async {
      final isolateError = pair as List<dynamic>;
      logger.error(
        isolateError.first.runtimeType,
        e: isolateError.first,
        st: StackTrace.fromString(isolateError.last.toString()),
      );
    }).sendPort,
  );

  PlatformDispatcher.instance.onError = (e, st) {
    logger.error(e.runtimeType, e: e, st: st);
    return true;
  };

  FlutterError.onError = (details) {
    final msg = details.toDiagnosticsNode().toDescription();
    logger.error(msg, e: details.exception, st: details.stack);
  };
}

void _initLifeCycle() {
  NamidaChannel.inst.addOnDestroy('main', () async {
    final mode = settings.player.killAfterDismissingApp.value;
    if (mode == KillAppMode.always || (mode == KillAppMode.ifNotPlaying && !Player.inst.isPlaying)) {
      await Player.inst.pause();
      await Player.inst.dispose();
    }
  });

  NamidaChannel.inst.addOnResume('main', () async {
    CurrentColor.inst.refreshColorsAfterResumeApp();
  });
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
        final paths = <String>[];
        final m3uPaths = <String>{};
        files.loop((f, _) {
          final realPath = f.realPath;
          if (realPath != null) {
            final path = realPath.replaceAll('\\', '');
            if (kM3UPlaylistsExtensions.any((ext) => path.endsWith(ext))) {
              m3uPaths.add(path);
            } else {
              paths.add(path);
            }
          } else {
            f.value?.split('\n').loop((e, index) {
              e.split('https://').loop((line, index) {
                if (line.isNotEmpty) paths.add("https://$line");
              });
            });
          }
        });

        if (m3uPaths.isNotEmpty) {
          final allTracks = await PlaylistController.inst.readM3UFiles(m3uPaths);
          final err = await playExternalFiles(allTracks.map((e) => e.path));
          if (err != null) showErrorPlayingFileSnackbar(error: err);
        } else if (paths.isNotEmpty) {
          final youtubeIds = paths.map((e) {
            final id = e.getYoutubeID;
            return id == '' ? null : id;
          }).whereType<String>();
          final ytPlaylists = paths.map((e) {
            final match = e.isEmpty ? null : NamidaLinkRegex.youtubePlaylistsLinkRegex.firstMatch(e)?[0];
            return match;
          }).whereType<String>();
          if (youtubeIds.isNotEmpty) {
            await _waitForFirstBuildContext.future;
            settings.onYoutubeLinkOpen.value.execute(youtubeIds);
          } else if (ytPlaylists.isNotEmpty) {
            for (final pl in ytPlaylists) {
              await OnYoutubeLinkOpenAction.alwaysAsk.executePlaylist(pl, context: rootContext);
            }
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

Future<bool> requestIgnoreBatteryOptimizations() async {
  final granted = await Permission.ignoreBatteryOptimizations.isGranted;
  if (granted) return true;
  settings.save(canAskForBatteryOptimizations: true);
  if (!settings.canAskForBatteryOptimizations) return false;

  snackyy(
    message: lang.IGNORE_BATTERY_OPTIMIZATIONS_SUBTITLE,
    displaySeconds: 5,
    top: false,
    isError: true,
    button: NamidaButton(
      text: lang.DONT_ASK_AGAIN,
      onPressed: () {
        Get.closeCurrentSnackbar();
        settings.save(canAskForBatteryOptimizations: false);
      },
    ),
  );
  await Future.delayed(const Duration(seconds: 1));
  final p = await Permission.ignoreBatteryOptimizations.request();
  return p.isGranted;
}

Future<bool> requestManageStoragePermission() async {
  Future<void> createDir() async => await Directory(settings.defaultBackupLocation.value).create(recursive: true);
  if (NamidaDeviceInfo.sdkVersion < 30) {
    await createDir();
    return true;
  }

  if (!await Permission.manageExternalStorage.isGranted) {
    await Permission.manageExternalStorage.request();
  }

  if (!await Permission.manageExternalStorage.isGranted || await Permission.manageExternalStorage.isDenied) {
    snackyy(title: lang.STORAGE_PERMISSION_DENIED, message: lang.STORAGE_PERMISSION_DENIED_SUBTITLE, isError: true);
    return false;
  }
  await createDir();
  return true;
}

Future<void> setJiffyLocale(String code) async {
  try {
    await Jiffy.setLocale(code);
  } catch (e) {
    try {
      await Jiffy.setLocale(code.split('_').first);
    } catch (_) {}
  }
}

BuildContext get rootContext => _initialContext;
late BuildContext _initialContext;
final _waitForFirstBuildContext = Completer<bool>();

class Namida extends StatelessWidget {
  final bool shouldShowOnBoarding;
  const Namida({super.key, required this.shouldShowOnBoarding});

  @override
  Widget build(BuildContext context) {
    // -- no need to listen, widget is rebuilt on applifecycle
    final showPipOnly = NamidaChannel.inst.isInPip.value && Player.inst.videoPlayerInfo != null;
    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        Visibility(
          maintainState: true,
          visible: !showPipOnly,
          child: Obx(
            () {
              final codes = settings.selectedLanguage.value.code.split('_');
              return Localizations(
                locale: Locale(codes.first, codes.last),
                delegates: const [
                  DefaultWidgetsLocalizations.delegate,
                  DefaultMaterialLocalizations.delegate,
                ],
                child: GetMaterialApp(
                  key: const Key('namida_app'),
                  debugShowCheckedModeBanner: false,
                  title: 'Namida',
                  // restorationScopeId: 'Namida',
                  builder: (context, widget) {
                    return ScrollConfiguration(
                      behavior: const ScrollBehaviorModified(),
                      child: Obx(
                        () {
                          final mode = settings.themeMode.value;
                          final useDarkTheme = mode == ThemeMode.dark || (mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                          final isLight = !useDarkTheme;
                          final theme = AppThemes.inst.getAppTheme(CurrentColor.inst.currentColorScheme, isLight);
                          NamidaNavigator.inst.setSystemUIOverlayStyleCustom(isLight);
                          return Theme(
                            data: theme,
                            child: widget!,
                          );
                        },
                      ),
                    );
                  },
                  home: MainPageWrapper(
                    shouldShowOnBoarding: shouldShowOnBoarding,
                    onContextAvailable: (ctx) {
                      _initialContext = ctx;
                      _waitForFirstBuildContext.isCompleted ? null : _waitForFirstBuildContext.complete(true);
                    },
                  ),
                ),
              );
            },
          ),
        ),

        // prevent accidental opening for drawer when performing back gesture
        SizedBox(
          width: 18.0,
          height: context.height * 0.8,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {},
          ),
        ),

        // prevent accidental miniplayer swipe when performing back gesture
        Positioned(
          right: 0,
          child: SizedBox(
            width: 8.0,
            height: context.height,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {},
            ),
          ),
        ),

        if (showPipOnly)
          Container(
            color: Colors.black,
            alignment: Alignment.topLeft,
            child: const NamidaVideoControls(
              key: Key('pip_widget_child'),
              isFullScreen: true,
              showControls: false,
              onMinimizeTap: null,
              isLocal: true,
            ),
          )
      ],
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
        return const BouncingScrollPhysicsModified();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysicsModified();
    }
  }
}
