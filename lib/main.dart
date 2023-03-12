// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:on_audio_edit/on_audio_edit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:namida/core/functions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/packages/inner_drawer.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/selected_tracks_preview.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/translations.dart';
import 'package:namida/ui/pages/homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // await Get.dialog(
  //   CustomBlurryDialog(
  //     title: Language.inst.STORAGE_PERMISSION,
  //     bodyText: Language.inst.STORAGE_PERMISSION_SUBTITLE,
  //     actions: [
  // CancelButton(),
  //       ElevatedButton(
  //         onPressed: () async {
  //           await Permission.storage.request();
  //           Get.close(1);
  //         },
  //         child: Text(Language.inst.GRANT_ACCESS),
  //       ),
  //     ],
  //   ),
  // );

  kAppDirectoryPath = await getExternalStorageDirectory().then((value) async => value?.path ?? await getApplicationDocumentsDirectory().then((value) => value.path));

  await Future.wait([
    Directory(kArtworksDirPath).create(),
    Directory(kPaletteDirPath).create(),
    Directory(kWaveformDirPath).create(),
    Directory(kVideosCachePath).create(),
    Directory(kVideosCacheTempPath).create(recursive: true),
    Directory(kLyricsDirPath).create(),
  ]);
  final paths = await ExternalPath.getExternalStorageDirectories();
  kStoragePaths.assignAll(paths);
  kDirectoriesPaths = paths.map((path) => "$path/${ExternalPath.DIRECTORY_MUSIC}").toSet();
  kDirectoriesPaths.add('${paths[0]}/Download/');
  kInternalAppDirectoryPath = "${paths[0]}/Namida";

  await SettingsController.inst.prepareSettingsFile();

  Get.put(() => ScrollSearchController());
  Get.put(() => VideoController());

  await Indexer.inst.prepareTracksFile();

  /// updates values on startup
  Indexer.inst.updateImageSizeInStorage();
  Indexer.inst.updateWaveformSizeInStorage();
  Indexer.inst.updateVideosSizeInStorage();

  PlaylistController.inst.preparePlaylistFile();
  VideoController.inst.getVideoFiles();

  await Player.inst.initializePlayer();
  await QueueController.inst.prepareLatestQueueFile();

  FlutterNativeSplash.remove();
  runApp(const MyApp());
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
    debugPrint('Reset SAF Failture');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        Get.focusScope?.unfocus();
      },
      child: Obx(
        () => GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Namida',
          theme: AppThemes.inst.getAppTheme(Colors.transparent, true),
          darkTheme: AppThemes.inst.getAppTheme(Colors.transparent, false),
          themeMode: SettingsController.inst.themeMode.value,
          translations: MyTranslation(),
          builder: (context, widget) {
            return ScrollConfiguration(behavior: const ScrollBehaviorModified(), child: widget!);
          },
          home: MainPageWrapper(),
        ),
      ),
    );
  }
}

class MainPageWrapper extends StatelessWidget {
  final Widget? child;
  final Widget? title;
  final List<Widget>? actions;
  final List<Widget>? actionsToAdd;
  final Color? colorScheme;
  MainPageWrapper({super.key, this.child, this.title, this.actions, this.actionsToAdd, this.colorScheme});

  final GlobalKey<InnerDrawerState> _innerDrawerKey = GlobalKey<InnerDrawerState>();
  void toggleDrawer() {
    if (child != null) {
      Get.offAll(() => MainPageWrapper());
    }
    _innerDrawerKey.currentState?.toggle();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Get.focusScope?.unfocus();
        return Future.value(true);
      },
      child: Obx(
        () => AnimatedTheme(
          duration: const Duration(milliseconds: 500),
          data: AppThemes.inst.getAppTheme(colorScheme ?? CurrentColor.inst.color.value, !context.isDarkMode),
          child: InnerDrawer(
            key: _innerDrawerKey,
            onTapClose: true,
            colorTransitionChild: context.theme.scaffoldBackgroundColor,
            colorTransitionScaffold: Colors.black54,
            offset: const IDOffset.only(left: 0.0),
            proportionalChildArea: true,
            borderRadius: 32.0.multipliedRadius,
            leftAnimationType: InnerDrawerAnimation.quadratic,
            rightAnimationType: InnerDrawerAnimation.quadratic,
            backgroundDecoration: BoxDecoration(color: context.theme.cardColor),
            duration: const Duration(milliseconds: 400),
            tapScaffoldEnabled: false,
            velocity: 0.01,
            innerDrawerCallback: (a) => print(a),
            leftChild: Container(
              color: context.theme.cardColor,
              child: Column(
                children: [
                  Expanded(
                    child: Obx(
                      () => ListView(
                        children: [
                          ...kLibraryTabsStock
                              .asMap()
                              .entries
                              .map(
                                (e) => NamidaDrawerListTile(
                                  enabled: SettingsController.inst.selectedLibraryTab.value == e.value.toEnum,
                                  title: e.value.toEnum.toText,
                                  icon: e.value.toEnum.toIcon,
                                  onTap: () async {
                                    ScrollSearchController.inst.animatePageController(e.value.toEnum.toInt);
                                    await Future.delayed(const Duration(milliseconds: 100));
                                    toggleDrawer();
                                  },
                                ),
                              )
                              .toList(),
                          NamidaDrawerListTile(
                            enabled: false,
                            title: Language.inst.QUEUES,
                            icon: Broken.driver,
                            onTap: () {
                              NamidaOnTaps.inst.openQueuesPage();
                              _innerDrawerKey.currentState?.toggle();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  NamidaDrawerListTile(
                    enabled: false,
                    title: Language.inst.SETTINGS,
                    icon: Broken.setting,
                    onTap: () {
                      Get.to(() => const SettingsPage());
                      toggleDrawer();
                    },
                  ),
                ],
              ),
            ),
            scaffold: Stack(
              children: [
                HomePage(
                  title: title,
                  actions: actions,
                  actionsToAdd: actionsToAdd,
                  onDrawerIconPressed: () => toggleDrawer(),
                  child: child,
                ),
                const Hero(tag: 'MINIPLAYER', child: MiniPlayerParent()),
                const Positioned(
                  bottom: 60.0,
                  child: SelectedTracksPreviewContainer(),
                ),
              ],
            ),
          ),
        ),
      ),
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

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _KeepAliveWrapperState createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class CustomReorderableDelayedDragStartListener extends ReorderableDragStartListener {
  final Duration delay;

  const CustomReorderableDelayedDragStartListener({
    this.delay = const Duration(milliseconds: 50),
    Key? key,
    required Widget child,
    required int index,
    bool enabled = true,
  }) : super(key: key, child: child, index: index, enabled: enabled);

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(delay: delay, debugOwner: this);
  }
}
