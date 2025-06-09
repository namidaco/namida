// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart' show FlutterVolumeController;
import 'package:http_cache_stream/http_cache_stream.dart';
import 'package:jiffy/jiffy.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:permission_handler/permission_handler.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/home_widget_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/shortcuts_controller.dart';
import 'package:namida/controller/smtc_controller.dart';
import 'package:namida/controller/storage_cache_manager.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/controller/version_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/controller/window_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main_page_wrapper.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/video_widget.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';

void main() {
  runZonedGuarded(
    mainInitialization,
    (error, stack) => logger.error(error.runtimeType, e: error, st: stack),
  );
}

void mainInitialization() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await WindowController.instance?.init();
  await HomeWidgetController.instance?.init();
  ShortcutsController.instance?.init();

  // -- x this makes some issues with GestureDetector
  // GestureBinding.instance.resamplingEnabled = true; // for 120hz displays, should make scrolling smoother.

  /// Getting Device info
  NamidaDeviceInfo.fetchAndroidInfo();
  NamidaDeviceInfo.fetchPackageInfo().then((value) {
    // -- in case full path was updated before fetching version
    logger.updateLoggerPath();
    NamidaTaggerController.inst.updateLogsPath();
  });
  NamidaDeviceInfo.sdkVersion = await NamidaChannel.inst.getPlatformSdk();

  /// if `true`:
  /// 1. onboarding screen will show
  /// 2. `indexer` and `latest queue` will be executed after permission is granted.
  bool shouldShowOnBoarding = false;

  if (!await requestStoragePermission(request: false)) {
    shouldShowOnBoarding = true;
  }

  NamicoDBWrapper.initialize();

  late final List<String> paths;
  Future<void> fetchAppData() async {
    final appDatas = await NamidaStorage.inst.getStorageDirectoriesAppData();
    AppDirs.USER_DATA = NamidaStorage.inst.getUserDataDirectory(appDatas);
    logger.updateLoggerPath();
    NamidaTaggerController.inst.updateLogsPath();
  }

  Future<void> fetchRootDir() async {
    Directory? dir;
    for (final fn in [pp.getApplicationSupportDirectory, pp.getApplicationDocumentsDirectory]) {
      try {
        dir = await fn();
      } catch (_) {}
    }

    String? path = dir?.path;
    if (path == null) {
      final appDatas = await NamidaStorage.inst.getStorageDirectoriesAppData();
      path = appDatas.firstOrNull;
    }
    AppDirs.ROOT_DIR = path ?? '';
  }

  await Future.wait([
    fetchAppData(),
    fetchRootDir(),
    NamidaStorage.inst.getStorageDirectories().then((value) => paths = value),
    NamidaStorage.inst.getStorageDirectoriesAppCache().then((value) => AppDirs.APP_CACHE = value.firstOrNull ?? ''),
  ]);
  _initErrorInterpreters();
  _cleanOldLogs.thready({'dirPath': AppDirs.LOGS_DIRECTORY, 'fileSuffix': AppPaths.getLogsSuffix()});

  if (paths.isEmpty) {
    final fallback = NamidaStorage.inst.defaultFallbackStoragePath;
    if (fallback != null) paths.add(fallback);
  }

  // -- creating directories
  AppDirs.values.loop((p) => Directory(p).createSync(recursive: true));

  kStoragePaths.addAll(paths);

  AppDirs.INTERNAL_STORAGE = FileParts.joinPath(paths[0], 'Namida');

  settings.prepareAllSettings();

  if (settings.directoriesToScan.value.isEmpty) {
    final downloadsFolder = await pp.getDownloadsDirectory().ignoreError().then((value) => value?.path) ?? FileParts.joinPath(paths[0], 'Download');
    settings.directoriesToScan.value.addAll([
      ...kStoragePaths.mappedUniqued((path) => FileParts.joinPath(path, 'Music')),
      downloadsFolder,
      AppDirs.INTERNAL_STORAGE,
    ]);
  }

  WindowController.instance?.restorePosition(); // -- requires settings

  await Future.wait([
    if (!shouldShowOnBoarding) Indexer.inst.prepareTracksFile(),
    Language.initialize(),
    Player.inst.initializePlayer(),
    PlaylistController.inst.prepareDefaultPlaylistsFileAsync(),
    YoutubePlaylistController.inst.prepareDefaultPlaylistsFileAsync(),
    YoutubeSubscriptionsController.inst.loadSubscriptionsFileAsync(),
    Rhttp.init().ignoreError().then((_) {
      final client = RhttpCompatibleClient.createSync();
      return HttpCacheManager.init(config: _HttpCacheCustomCacheConfig._(client));
    }).ignoreError(),
  ]);

  if (InternalPlayerType.platformDefault.shouldInitializeMPV) {
    mk.MediaKit.ensureInitialized();
  }

  ConnectivityController.inst.initialize();
  NamidaChannel.inst.setCanEnterPip(settings.enablePip.value);

  /// updates values on startup
  Indexer.inst.calculateAllImageSizesInStorage();
  Indexer.inst.updateColorPalettesSizeInStorage();
  if (!shouldShowOnBoarding) {
    if (settings.refreshOnStartup.value) {
      Indexer.inst.refreshLibraryAndCheckForDiff(allowDeletion: false, showFinishedSnackbar: false);
    } else {
      Indexer.inst.getAudioFiles(); // main reason is to refresh fallback covers
    }
  }
  if (!shouldShowOnBoarding) {
    BackupController.inst.checkForAutoBackup();
  }

  VideoController.inst.initialize();
  const StorageCacheManager().trimExtraFiles();

  NamidaDeviceInfo.fetchDeviceId();
  VersionController.inst.ensureInitialized();

  YoutubeInfoController.initialize(); // for queue to display properly
  YoutubeAccountController.initialize();

  if (!shouldShowOnBoarding) await QueueController.inst.prepareLatestQueueAsync();

  PlaylistController.inst.prepareAllPlaylists();
  YoutubePlaylistController.inst.prepareAllPlaylists();
  QueueController.inst.prepareAllQueuesFile();
  YoutubeController.inst.loadDownloadTasksInfoFileAsync(); // no longer waiting for it

  CurrentColor.inst.initialize();
  FlutterNativeSplash.remove();

  HistoryController.inst.prepareHistoryFile().then((_) => Indexer.inst.sortMediaTracksAndSubListsAfterHistoryPrepared());
  YoutubeHistoryController.inst.prepareHistoryFile();

  YoutubeInfoController.utils.fillBackupInfoMap(); // for history videos info.

  _initializeIntenties();

  SystemChrome.setPreferredOrientations(kDefaultOrientations);
  NamidaNavigator.setSystemUIImmersiveMode(false);
  FlutterDisplayMode.setHighRefreshRate().ignoreError();

  NamidaNavigator.setDefaultSystemUIOverlayStyle();

  ScrollSearchController.inst.initialize();
  NotificationManager.init();
  FlutterVolumeController.updateShowSystemUI(false);

  runApp(Namida(shouldShowOnBoarding: shouldShowOnBoarding));

  // CurrentColor.inst.generateAllColorPalettes();
  FoldersController.tracks.onFirstLoad();
  FoldersController.videos.onFirstLoad();

  _initLifeCycle();
}

void _cleanOldLogs(Map params) {
  final dirPath = params['dirPath'] as String;
  final fileSuffix = params['fileSuffix'] as String?;
  Directory(dirPath).listSync().loop((e) {
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

  FlutterError.onError = kDebugMode
      ? (details) {
          final msg = details.toString();
          logger.error(msg, e: details.exception, st: details.stack);
        }
      : (details) {
          final msg = details.toDiagnosticsNode().toDescription();
          logger.error(msg, e: details.exception, st: details.stack);
        };
}

void _initLifeCycle() {
  NamidaChannel.inst.addOnDestroy(() async {
    final mode = settings.player.killAfterDismissingApp.value;
    if (mode == KillAppMode.always || (mode == KillAppMode.ifNotPlaying && !Player.inst.playWhenReady.value)) {
      await Player.inst.pause();
      await Player.inst.dispose();
    }
  });

  NamidaChannel.inst.addOnResume(CurrentColor.inst.refreshColorsAfterResumeApp);
  NamidaChannel.inst.addOnResume(WaveformController.inst.calculateUIWaveform);
  NamidaChannel.inst.addOnResume(() async => FlutterDisplayMode.setHighRefreshRate().ignoreError());
}

void _initializeIntenties() {
  Future<void> clearIntentCachedFiles() async {
    final cacheDir = await pp.getTemporaryDirectory();
    return Isolate.run(
      () {
        final items = cacheDir.listSyncSafe();
        items.loop(
          (item) {
            if (item is File) {
              try {
                item.deleteSync();
              } catch (_) {}
            }
          },
        );
      },
    );
  }

  /// Clearing files cached by intents
  clearIntentCachedFiles();

  void showErrorPlayingFileSnackbar({String? error}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final errorMessage = error != null ? '($error)' : '';
      snackyy(title: lang.ERROR, message: '${lang.COULDNT_PLAY_FILE} $errorMessage');
    });
  }

  void playFiles(List<SharedFile> files) {
    // -- deep links
    if (files.length == 1) {
      final linkRaw = files.first.value;
      if (linkRaw != null) {
        final link = linkRaw.replaceAll(r'\', '');
        if (link.startsWith('app://patreonauth.msob7y.namida')) {
          final link = linkRaw.replaceAll(r'\', '');
          YoutubeAccountController.membership.redirectUrlCompleter?.completeIfWasnt(link);
          return;
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (files.isNotEmpty) {
        final paths = <String>[];
        final m3uPaths = <String>{};
        files.loop((f) {
          final realPath = f.realPath;
          if (realPath != null) {
            final path = realPath.replaceAll(r'\', '');
            if (NamidaFileExtensionsWrapper.m3u.isPathValid(path)) {
              m3uPaths.add(path);
            } else {
              paths.add(path);
            }
          } else {
            f.value?.split('\n').loop((e) {
              e.split('https://').loop((line) {
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
          final ytPlaylistsIds = paths.map((e) {
            final matchPlId = e.isEmpty ? null : NamidaLinkUtils.extractPlaylistId(e);
            return matchPlId;
          }).whereType<String>();
          if (youtubeIds.isNotEmpty) {
            await _waitForFirstBuildContext.future;
            settings.youtube.onYoutubeLinkOpen.value.execute(youtubeIds);
          } else if (ytPlaylistsIds.isNotEmpty) {
            for (final plid in ytPlaylistsIds) {
              YTHostedPlaylistSubpage.fromId(playlistId: plid, userPlaylist: null).navigate();
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

  if (NamidaFeaturesVisibility.recieveSharingIntents) {
    // -- Recieving Initial Android Shared Intent.
    FlutterSharingIntent.instance.getInitialSharing().then(playFiles);

    // -- Listening to Android Shared Intents.
    FlutterSharingIntent.instance.getMediaStream().listen(
          playFiles,
          onError: (err) => showErrorPlayingFileSnackbar(error: err.toString()),
        );
  }
}

/// returns [true] if played successfully.
Future<String?> playExternalFiles(Iterable<String> paths) async {
  try {
    final trs = await Indexer.inst.convertPathsToTracksAndAddToLists(paths);
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
  if (!settings.canAskForBatteryOptimizations) return false;

  snackyy(
    message: lang.IGNORE_BATTERY_OPTIMIZATIONS_SUBTITLE,
    displayDuration: SnackDisplayDuration.eternal,
    top: false,
    isError: true,
    button: (
      lang.DONT_ASK_AGAIN,
      () => settings.save(canAskForBatteryOptimizations: false),
    ),
  );
  await Future.delayed(const Duration(seconds: 1));
  final p = await Permission.ignoreBatteryOptimizations.request();
  return p.isGranted;
}

Future<bool> requestManageStoragePermission({bool request = true, bool showError = true}) async {
  Future<void> createDir() async => await Directory(AppDirs.INTERNAL_STORAGE).create(recursive: true);
  if (!NamidaFeaturesVisibility.shouldRequestManageAllFilesPermission) {
    await createDir();
    return true;
  }

  if (request && !await Permission.manageExternalStorage.isGranted) {
    await Permission.manageExternalStorage.request();
  }

  if (!await Permission.manageExternalStorage.isGranted || await Permission.manageExternalStorage.isDenied) {
    if (showError) snackyy(title: lang.STORAGE_PERMISSION_DENIED, message: lang.STORAGE_PERMISSION_DENIED_SUBTITLE, isError: true);
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
      await Jiffy.setLocale(code.splitFirst('_'));
    } catch (_) {}
  }
}

BuildContext get rootContext => _initialContext;
late BuildContext _initialContext;
final _waitForFirstBuildContext = Completer<bool>();

class Namida extends StatelessWidget {
  final bool shouldShowOnBoarding;
  const Namida({super.key, required this.shouldShowOnBoarding});

  Widget buildMainApp(Widget widget, Brightness? platformBrightness) => Directionality(
        textDirection: TextDirection.ltr,
        child: ScrollConfiguration(
          behavior: const ScrollBehaviorModified(),
          child: ObxO(
            rx: settings.selectedLanguage,
            builder: (context, selectedLanguage) {
              final codes = selectedLanguage.code.split('_');
              return Localizations(
                locale: Locale(codes.first, codes.length > 1 ? codes.last : null),
                delegates: const [
                  DefaultWidgetsLocalizations.delegate,
                  DefaultMaterialLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                child: Obx(
                  (context) {
                    final mode = settings.themeMode.valueR;
                    final useDarkTheme = mode == ThemeMode.dark || (mode == ThemeMode.system && platformBrightness == Brightness.dark);
                    final isLight = !useDarkTheme;
                    final theme = AppThemes.inst.getAppTheme(CurrentColor.inst.currentColorScheme, isLight);
                    NamidaNavigator.inst.setSystemUIOverlayStyleCustom(isLight);
                    return Theme(
                      data: theme,
                      child: widget,
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final shouldAddEdgeAbsorbers = Platform.isAndroid || Platform.isIOS;
    final mainPageWrapper = MainPageWrapper(
      shouldShowOnBoarding: widget.shouldShowOnBoarding,
      onContextAvailable: (ctx) {
        _initialContext = ctx;
        _waitForFirstBuildContext.isCompleted ? null : _waitForFirstBuildContext.complete(true);
      },
    );
    return ObxO(
      rx: NamidaChannel.inst.isInPip,
      builder: (context, showPipOnly) => Container(
        color: Colors.black,
        alignment: Alignment.topLeft,
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            Visibility(
              maintainState: true,
              visible: !showPipOnly,
              child: ObxO(
                rx: settings.fontScaleFactor,
                builder: (context, fontScaleFactor) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScaleFactor)),
                  child: MaterialApp(
                    color: kDefaultIconLightColor,
                    key: const Key('namida_app'),
                    debugShowCheckedModeBanner: false,
                    navigatorKey: namida.rootNavigatorKey,
                    title: 'Namida',
                    // restorationScopeId: 'Namida',
                    builder: (context, widget) {
                      Brightness platformBrightness = MediaQuery.platformBrightnessOf(context);
                      // overlay entries get rebuilt on any insertion/removal, so we create app here.

                      Widget mainApp = buildMainApp(widget!, platformBrightness);

                      return Overlay(
                        initialEntries: [
                          OverlayEntry(builder: (context) {
                            final newPlatformBrightness = MediaQuery.platformBrightnessOf(context);
                            if (newPlatformBrightness != platformBrightness) {
                              platformBrightness = newPlatformBrightness;
                              mainApp = buildMainApp(widget, platformBrightness);
                              YoutubeMiniplayerUiController.inst.startDimTimer(brightness: platformBrightness);
                            }
                            return mainApp;
                          }),
                        ],
                      );
                    },
                    home: mainPageWrapper,
                  ),
                ),
              ),
            ),

            // prevent accidental opening for drawer when performing back gesture
            if (shouldAddEdgeAbsorbers)
              SizedBox(
                width: 18.0,
                height: context.height * 0.8,
                child: HorizontalDragDetector(
                  onUpdate: (_) {},
                ),
              ),

            // prevent accidental miniplayer/queue swipe up when performing home scween gesture
            if (shouldAddEdgeAbsorbers)
              SizedBox(
                height: 18.0,
                width: context.height,
                child: VerticalDragDetector(
                  onUpdate: (_) {},
                ),
              ),

            // prevent accidental miniplayer swipe when performing back gesture
            if (shouldAddEdgeAbsorbers)
              Positioned(
                right: 0,
                child: SizedBox(
                  width: 12.0,
                  height: context.height,
                  child: HorizontalDragDetector(
                    onUpdate: (_) {},
                  ),
                ),
              ),

            if (showPipOnly)
              const NamidaVideoControls(
                key: Key('pip_widget_child'),
                isFullScreen: true,
                showControls: false,
                onMinimizeTap: null,
                isLocal: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _HttpCacheCustomCacheConfig extends GlobalCacheConfig {
  _HttpCacheCustomCacheConfig._(RhttpCompatibleClient client)
      : super(
          cacheDirectory: Directory(''),
          maxBufferSize: 5 * 1024 * 1024,
          rangeRequestSplitThreshold: (0.5 * 1024 * 1024).round(),
          customHttpClient: client,
        );
}

class ScrollBehaviorModified extends ScrollBehavior {
  const ScrollBehaviorModified();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

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
