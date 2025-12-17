// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart' show FlutterVolumeController;
import 'package:http_cache_stream/http_cache_stream.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:path_provider/path_provider.dart' as pp;
import 'package:permission_handler/permission_handler.dart';
import 'package:rhttp/rhttp.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
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

void main(List<String> args) {
  runZonedGuarded(
    () async {
      final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
      runApp(const Namida());
    },
    (error, stack) => logger.error(error.runtimeType, e: error, st: stack),
    zoneValues: {
      'args': args,
    },
  );
}

Future<bool> _mainAppInitialization() async {
  List<String>? args;

  /// if `true`:
  /// 1. onboarding screen will show
  /// 2. `indexer` and `latest queue` will be executed after permission is granted.
  bool shouldShowOnBoarding = false;

  try {
    if (Platform.isAndroid) {
      // -- its not just obtaining sdk version.. we are making sure method channels are properly initialized on native side
      // -- cuz it can throw on some devices
      int tryCount = 0;
      while (NamidaDeviceInfo.sdkVersion < 0) {
        tryCount++;
        try {
          NamidaDeviceInfo.sdkVersion = await NamidaChannel.inst.getPlatformSdk();
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        if (tryCount > 200) {
          // 200*200ms = 40s
          exit(1);
        }
      }
    }

    await [
      WindowController.instance?.init(),
      SMTCController.instance?.init(),
      HomeWidgetController.instance?.init(),
    ].executeAllAndSilentReportErrors();

    if (Platform.isWindows) {
      args = Zone.current['args'] as List<String>? ?? [];
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        "namida_instance",
        bringWindowToFront: true,
        onSecondWindow: (args) => _NamidaReceiveIntentManager.executeReceivedItems(args, (p) => p, (p) => p),
      );
    }

    ShortcutsController.instance?.init();

    // -- x this makes some issues with GestureDetector
    // GestureBinding.instance.resamplingEnabled = true; // for 120hz displays, should make scrolling smoother.

    /// Getting Device info
    NamidaDeviceInfo.fetchDeviceInfo();
    NamidaDeviceInfo.fetchPackageInfo().then((value) {
      // -- in case full path was updated before fetching version
      logger.updateLoggerPath();
      NamidaTaggerController.inst.updateLogsPath();
    });

    NamicoDBWrapper.initialize();

    Future<void> fetchAppData() async {
      final appDatas = await NamidaStorage.inst.getStorageDirectoriesAppData();
      AppDirs.USER_DATA = NamidaStorage.inst.getUserDataDirectory(appDatas);
      logger.updateLoggerPath();
      NamidaTaggerController.inst.updateLogsPath();
    }

    Future<void> fetchRootDir() async {
      Directory? dir;
      for (final fn in [
        pp.getApplicationSupportDirectory,
        pp.getApplicationDocumentsDirectory,
      ]) {
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

    var paths = <String>[];

    await [
      fetchAppData(),
      fetchRootDir(),
      NamidaStorage.inst.getStorageDirectories().then((value) => paths = value),
      NamidaStorage.inst.getStorageDirectoriesAppCache().then((value) => AppDirs.APP_CACHE = value.firstOrNull ?? ''),
    ].executeAllAndSilentReportErrors();

    // -- sdk must be initialized first
    if (!await requestStoragePermission(request: false)) {
      shouldShowOnBoarding = true;
    }

    if (paths.isEmpty) {
      final fallback = NamidaStorage.inst.defaultFallbackStoragePath;
      if (fallback != null) paths.add(fallback);
    }
    kStoragePaths.addAll(paths);
    AppDirs.INTERNAL_STORAGE = FileParts.joinPath(paths[0], 'Namida');

    _initErrorInterpreters();
    _cleanOldLogsSync.thready([AppDirs.LOGS_DIRECTORY, AppPaths.getLogsSuffix()]);

    // -- creating directories
    await AppDirs.values.map((p) => Directory(p).create(recursive: true)).executeAllAndSilentReportErrors();

    if (NamidaFeaturesVisibility.isStoragePermissionNotRequired) {
      if (!shouldShowOnBoarding) {
        final settingsExist = await File(AppPaths.SETTINGS).exists().ignoreError() ?? false;
        shouldShowOnBoarding = !settingsExist;
      }
    }

    await settings.prepareAllSettings();
    ShortcutsController.instance?.initUserShortcutsFromSettings();

    if (settings.directoriesToScan.value.isEmpty) {
      final downloadsFolder = await pp.getDownloadsDirectory().ignoreError().then((value) => value?.path) ?? FileParts.joinPath(paths[0], 'Download');
      settings.directoriesToScan.value.addAll([
        ...kStoragePaths.mappedUniqued((path) => FileParts.joinPath(path, 'Music')),
        downloadsFolder,
        AppDirs.INTERNAL_STORAGE,
      ]);
    }
  } catch (e, st) {
    logger.error('_mainAppInitialization', e: e, st: st);
  }

  try {
    WindowController.instance?.restorePosition(); // -- requires settings

    final ytInfoInitSyncItemsCompleter = Completer<void>();

    /// even tho we don't really need to wait for queue, it's better as to
    /// minimize startup lag as this changes some app-level vars like color scheme
    FutureOr<void> prepareLatestQueue() {
      if (!shouldShowOnBoarding) {
        return ytInfoInitSyncItemsCompleter.future.whenComplete(QueueController.inst.prepareLatestQueueAsync);
      }
    }

    YoutubeInfoController.initialize(ytInfoInitSyncItemsCompleter).catchError(logger.report);

    if (settings.player.internalPlayer.value.shouldInitializeMPV) {
      mk.MediaKit.ensureInitialized.ignoreError();
    }

    await [
      if (!shouldShowOnBoarding) Indexer.inst.prepareTracksFile(startupBoost: true),
      Language.initialize(),
      Player.inst.initializePlayer().whenComplete(prepareLatestQueue),
      PlaylistController.inst.prepareDefaultPlaylistsFileAsync(),
      YoutubePlaylistController.inst.prepareDefaultPlaylistsFileAsync(),
      YoutubeSubscriptionsController.inst.loadSubscriptionsFileAsync(),
      ConnectivityController.inst.initialize(),
      FlutterDisplayMode.setHighRefreshRate().ignoreError(), // ignore cuz whatever
      NamidaNavigator.setSystemUIImmersiveMode(false),
      Rhttp.init().then((_) => RhttpCompatibleClient.create().then((client) => HttpCacheManager.init(config: _HttpCacheCustomCacheConfig._(client)))),
      ytInfoInitSyncItemsCompleter.future,
    ].executeAllAndSilentReportErrors();

    NamidaNavigator.setDefaultSystemUIOverlayStyle.ignoreError();
    ScrollSearchController.inst.initialize();
  } catch (e, st) {
    logger.error('_mainAppInitialization 2', e: e, st: st);
  }

  if (args != null && args.isNotEmpty) {
    _NamidaReceiveIntentManager.executeReceivedItems(args, (p) => p, (p) => p);
  }
  return shouldShowOnBoarding;
}

Future<void> _secondaryAppInitialization(bool shouldShowOnBoarding) async {
  try {
    _initializeIntenties();
    _initLifeCycle();

    YoutubeAccountController.initialize();

    await [
      YoutubeInfoController.utils.fillBackupInfoMap(), // for history videos info.

      HistoryController.inst.prepareHistoryFile().then((_) => Indexer.inst.sortMediaTracksAndSubListsAfterHistoryPrepared()), //
      YoutubeHistoryController.inst.prepareHistoryFile(),

      PlaylistController.inst.prepareAllPlaylists(),
      YoutubePlaylistController.inst.prepareAllPlaylists(),

      VideoController.inst.initialize(),
      YoutubeController.inst.loadDownloadTasksInfoFileAsync(),

      NotificationManager.init(),
      FlutterVolumeController.updateShowSystemUI(false),
      NamidaChannel.inst.setCanEnterPip(settings.enablePip.value),
    ].executeAllAndSilentReportErrors();

    await [
      QueueController.inst.prepareAllQueuesFile(),

      if (!shouldShowOnBoarding)
        if (settings.refreshOnStartup.value)
          Indexer.inst.refreshLibraryAndCheckForDiff(allowDeletion: false, showFinishedSnackbar: false)
        else
          Indexer.inst.getAudioFiles() // main reason is to refresh fallback covers
    ].executeAllAndSilentReportErrors();

    // CurrentColor.inst.initialize(); // --> !can block?

    if (!shouldShowOnBoarding) await BackupController.inst.checkForAutoBackup(); // --> !can block
    const StorageCacheManager().trimExtraFiles();
    VersionController.inst.ensureInitialized();
    _clearIntentCachedFiles(); // clearing files cached by intents
    // CurrentColor.inst.generateAllColorPalettes();
  } catch (e, st) {
    logger.error('_secondaryAppInitialization', e: e, st: st);
  }
}

void _cleanOldLogsSync(List params) {
  String dirPath = params[0];
  String? fileSuffix = params[1];
  Directory(dirPath).listSyncSafe().loop((e) {
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
  NamidaChannel.inst.addOnResume(() {
    final context = namida.context;
    if (context != null) {
      try {
        _NamidaState.refreshSystemBarsColors(context, forceRefresh: true);
      } catch (_) {}
    }
  });
  NamidaChannel.inst.addOnResume(WaveformController.inst.calculateUIWaveform);
  NamidaChannel.inst.addOnResume(() async => FlutterDisplayMode.setHighRefreshRate().ignoreError());
}

Future<void> _clearIntentCachedFiles() async {
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

void _initializeIntenties() {
  if (NamidaFeaturesVisibility.recieveSharingIntents) {
    // -- Recieving Initial Android Shared Intent.
    FlutterSharingIntent.instance.getInitialSharing().then(
          (items) => _NamidaReceiveIntentManager.executeReceivedItems(items, (f) => f.value, (f) => f.realPath),
        );

    // -- Listening to Android Shared Intents.
    FlutterSharingIntent.instance.getMediaStream().listen(
          (items) => _NamidaReceiveIntentManager.executeReceivedItems(items, (f) => f.value, (f) => f.realPath),
          onError: (err) => _NamidaReceiveIntentManager.showErrorPlayingFileSnackbar(error: err.toString()),
        );
  }
}

/// Granting Storage Permission.
/// Requesting Granular media permissions for Android 13 (API 33) doesnt work for some reason.
/// Currently the target API is set to 32.
/// [request] will prompt dialog if not granted.
Future<bool> requestStoragePermission({bool request = true}) async {
  bool granted = false;

  final permissionsToRequest = <Permission>[];
  if (NamidaDeviceInfo.sdkVersion < 33) {
    permissionsToRequest.add(Permission.storage);
  } else {
    permissionsToRequest.add(Permission.audio);
    permissionsToRequest.add(Permission.videos);
    permissionsToRequest.add(Permission.photos);
  }

  if (await permissionsToRequest.anyAsync((element) => element.isPermanentlyDenied)) {
    if (request) {
      // -- user denied, should open settings.
      await openAppSettings();
    }
  } else if (await permissionsToRequest.anyAsync((element) => element.isDenied)) {
    if (request) {
      final statuses = await permissionsToRequest.request();
      if (statuses.values.any((st) => st.isPermanentlyDenied)) {
        await openAppSettings();
      }
      granted = statuses.values.every((st) => st.isGranted);
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

Future<bool> requestManageStoragePermission({bool request = true, bool showError = true, bool ensureDirectoryCreated = false}) async {
  Future<void> createDir() async {
    if (!ensureDirectoryCreated) return;
    final dir = Directory(AppDirs.INTERNAL_STORAGE);
    if (!await dir.exists()) await dir.create(recursive: true);
  }

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

BuildContext get rootContext => namida.rootNavigatorKey.currentContext!;

class Namida extends StatefulWidget {
  const Namida({super.key});

  @override
  State<Namida> createState() => _NamidaState();
}

class _NamidaState extends State<Namida> {
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
                    final isLight = mode.isLight(platformBrightness);
                    final theme = AppThemes.inst.getAppTheme(CurrentColor.inst.currentColorScheme, isLight);
                    final mainChild = WindowController.instance?.usingCustomWindowTitleBar == true
                        ? Column(
                            children: [
                              const NamidaDesktopAppBar(),
                              Expanded(
                                child: widget,
                              ),
                            ],
                          )
                        : widget;

                    return Theme(
                      data: theme,
                      child: mainChild,
                    );
                  },
                ),
              );
            },
          ),
        ),
      );

  bool? _shouldShowOnBoarding;

  @override
  void initState() {
    super.initState();
    _initStuff();
  }

  Future<void> _initStuff() async {
    final shouldShowOnBoarding = await _mainAppInitialization();
    setState(() => _shouldShowOnBoarding = shouldShowOnBoarding);

    FlutterNativeSplash.remove();
    Timer(
      Duration.zero,
      () => _secondaryAppInitialization(shouldShowOnBoarding),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSystemBarsColors());
    settings.themeMode.addListener(_refreshSystemBarsColors);
  }

  static void refreshSystemBarsColors(BuildContext context, {bool forceRefresh = false}) {
    final mode = settings.themeMode.value;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isLight = mode.isLight(platformBrightness);
    NamidaNavigator.inst.setSystemUIOverlayStyleCustom(isLight, forceRefresh: forceRefresh);
  }

  void _refreshSystemBarsColors() {
    return refreshSystemBarsColors(context);
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowOnBoarding = _shouldShowOnBoarding;
    if (shouldShowOnBoarding == null) return const SizedBox();

    final shouldAddEdgeAbsorbers = Platform.isAndroid || Platform.isIOS;
    final mainPageWrapper = MainPageWrapper(shouldShowOnBoarding: shouldShowOnBoarding);
    Widget finalApp = Directionality(
      textDirection: TextDirection.ltr,
      child: ObxO(
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
                  forceEnableSponsorBlock: false,
                  onMinimizeTap: null,
                  isLocal: true,
                ),
            ],
          ),
        ),
      ),
    );
    return NamidaFeaturesVisibility.recieveDragAndDrop
        ? _NamidaDropRegion(
            child: finalApp,
          )
        : finalApp;
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
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();

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
        return const BouncingScrollPhysicsModified();
    }
  }
}

class _NamidaReceiveIntentManager {
  static void executeReceivedItems<T>(List<T> files, String? Function(T f) valueCallback, String? Function(T f) realPathCallback) {
    // -- deep links
    if (files.length == 1) {
      final linkRaw = valueCallback(files.first);
      if (linkRaw != null) {
        final link = Platform.isAndroid ? linkRaw.replaceAll(r'\', '') : linkRaw;
        if (link.startsWith('app://patreonauth.msob7y.namida')) {
          final link = Platform.isAndroid ? linkRaw.replaceAll(r'\', '') : linkRaw;
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
          final realPath = realPathCallback(f);
          if (realPath != null) {
            final path = Platform.isAndroid ? realPath.replaceAll(r'\', '') : realPath;
            if (NamidaFileExtensionsWrapper.m3u.isPathValid(path)) {
              m3uPaths.add(path);
            } else {
              paths.add(path);
            }
          } else {
            valueCallback(f)?.split('\n').loop((e) {
              e.split('https://').loop((line) {
                if (line.isNotEmpty) paths.add("https://$line");
              });
            });
          }
        });

        if (m3uPaths.isNotEmpty) {
          final allTracks = await PlaylistController.inst.readM3UFiles(m3uPaths);
          final err = await _extractAndPlayExternalFiles(allTracks.map((e) => e.path));
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
            settings.youtube.onYoutubeLinkOpen.value.execute(youtubeIds);
          } else if (ytPlaylistsIds.isNotEmpty) {
            for (final plid in ytPlaylistsIds) {
              YTHostedPlaylistSubpage.fromId(playlistId: plid, userPlaylist: null).navigate();
            }
          } else {
            final existing = paths.where((element) => File(element).existsSync()); // this for sussy links
            final err = await _extractAndPlayExternalFiles(existing);
            if (err != null) showErrorPlayingFileSnackbar(error: err);
          }
        }
      }
    });
  }

  static Future<String?> _extractAndPlayExternalFiles(Iterable<String> paths) async {
    try {
      final trs = await Indexer.inst.convertPathsToTracksAndAddToLists(paths);
      if (trs.isNotEmpty) {
        await Player.inst.playOrPause(0, trs, QueueSource.externalFile);
        return null;
      } else {
        return 'Empty List (original ${paths.length} | extracted: ${trs.length})';
      }
    } catch (e) {
      return e.toString();
    }
  }

  static void showErrorPlayingFileSnackbar({String? error}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final errorMessage = error != null ? '($error)' : '';
      snackyy(title: lang.ERROR, message: '${lang.COULDNT_PLAY_FILE} $errorMessage');
    });
  }
}

class _NamidaDropRegion extends StatelessWidget {
  final Widget child;
  const _NamidaDropRegion({required this.child});

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        final item = event.session.items.first;
        if (item.canProvide(Formats.plainText)) {
          return DropOperation.link;
        }
        if (item.canProvide(Formats.fileUri) || event.session.allowedOperations.contains(DropOperation.copy)) {
          return DropOperation.copy;
        }

        return DropOperation.none;
      },
      onPerformDrop: (event) async {
        final finalData = <String>[];
        for (final item in event.session.items) {
          final reader = item.dataReader;
          if (reader == null) continue;
          if (reader.canProvide(Formats.plainText)) {
            reader.getValue<String>(
              Formats.plainText,
              (value) {
                if (value != null) {
                  finalData.add(value);
                }
              },
            );
          }
          if (reader.canProvide(Formats.fileUri)) {
            reader.getValue(
              Formats.fileUri,
              (value) {
                if (value != null) {
                  finalData.add(value.toFilePath());
                }
              },
            );
          }
        }
        _NamidaReceiveIntentManager.executeReceivedItems(finalData, (f) => f, (f) => f);
      },
      child: child,
    );
  }
}
