import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:on_audio_edit/on_audio_edit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:namida/packages/miniplayer.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/folders_controller.dart';
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

  await GetStorage.init('NamidaSettings');

  kAppDirectoryPath = await getExternalStorageDirectory().then((value) async => value?.path ?? await getApplicationDocumentsDirectory().then((value) => value.path));

  await Directory(kArtworksDirPath).create();
  await Directory(kArtworksCompDirPath).create();
  await Directory(kPaletteDirPath).create();
  await Directory(kWaveformDirPath).create();
  await Directory(kVideosCachePath).create();
  await Directory(kVideosCacheTempPath).create();

  final paths = await ExternalPath.getExternalStorageDirectories();
  kStoragePaths.assignAll(paths);
  kDirectoriesPaths = paths.map((path) => "$path/${ExternalPath.DIRECTORY_MUSIC}").toSet();
  kDirectoriesPaths.add('${paths[0]}/Download/');
  kInternalAppDirectoryPath = "${paths[0]}/Namida";

  Get.put(() => SettingsController());
  Get.put(() => ScrollSearchController());
  Get.put(() => Player());
  Get.put(() => VideoController());
  Get.put(() => Folders());
  await Player.inst.initializePlayer();

  final tfe = await File(kTracksFilePath).exists() && await File(kTracksFilePath).stat().then((value) => value.size > 5);
  if (tfe) {
    await Indexer.inst.prepareTracksFile(tfe);
  } else {
    Indexer.inst.prepareTracksFile(tfe);
  }
  await PlaylistController.inst.preparePlaylistFile();
  // QueueController.inst.prepareQueuesFile();
  await QueueController.inst.prepareLatestQueueFile();
  await VideoController.inst.getVideoFiles();

  /// updates values on startup
  Indexer.inst.updateImageSizeInStorage();
  Indexer.inst.updateWaveformSizeInStorage();
  Indexer.inst.updateVideosSizeInStorage();

  runApp(const MyApp());
}

Future<bool> requestManageStoragePermission() async {
  if (kSdkVersion < 30) {
    return true;
  }
  // final shouldRequest = !await Permission.manageExternalStorage.isGranted || await Permission.manageExternalStorage.isDenied;
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
    return Obx(
      () => Listener(
        onPointerDown: (_) {
          // FocusScopeNode currentFocus = FocusScope.of(context);
          // if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
          //   currentFocus.focusedChild?.unfocus();
          // }
          Get.focusScope?.unfocus();
        },
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Namida',
          theme: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, true),
          darkTheme: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, false),
          themeMode: SettingsController.inst.themeMode.value,
          translations: MyTranslation(),
          builder: (context, widget) {
            return ScrollConfiguration(behavior: const ScrollBehaviorModified(), child: widget!);
          },
          home: const MainPageWrapper(),
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
  const MainPageWrapper({super.key, this.child, this.title, this.actions, this.actionsToAdd});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Get.focusScope?.unfocus();
        return Future.value(true);
      },
      child: Stack(
        children: [
          HomePage(title: title, actions: actions, actionsToAdd: actionsToAdd, child: child),
          Hero(tag: 'MINIPLAYER', child: MiniPlayerParent()),
          const Positioned(
            bottom: 60.0,
            child: SelectedTracksPreviewContainer(),
          ),
        ],
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
    this.delay = const Duration(milliseconds: 1),
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
