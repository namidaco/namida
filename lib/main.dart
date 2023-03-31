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
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/functions.dart';
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

  Future<void> createDirectories(List<String> paths) async {
    for (final p in paths) {
      await Directory(p).create(recursive: true);
    }
  }

  await createDirectories([
    kArtworksDirPath,
    kPaletteDirPath,
    kWaveformDirPath,
    kVideosCachePath,
    kVideosCacheTempPath,
    kLyricsDirPath,
    kMetadataDirPath,
    kMetadataCommentsDirPath,
  ]);

  final paths = await ExternalPath.getExternalStorageDirectories();
  kStoragePaths.assignAll(paths);
  kDirectoriesPaths = paths.map((path) => "$path/${ExternalPath.DIRECTORY_MUSIC}").toSet();
  kDirectoriesPaths.add('${paths[0]}/Download/');
  kInternalAppDirectoryPath = "${paths[0]}/Namida";

  Get.put(() => ScrollSearchController());
  Get.put(() => VideoController());

  await SettingsController.inst.prepareSettingsFile();
  await Indexer.inst.prepareTracksFile();

  /// updates values on startup
  Indexer.inst.updateImageSizeInStorage();
  Indexer.inst.updateWaveformSizeInStorage();
  Indexer.inst.updateVideosSizeInStorage();

  VideoController.inst.getVideoFiles();

  FlutterNativeSplash.remove();

  // playlists should be prepared first since it can used as reference in queues.
  await PlaylistController.inst.prepareDefaultPlaylistsFile();

  PlaylistController.inst.preparePlaylistFile();
  QueueController.inst.prepareQueuesFile();

  await QueueController.inst.prepareLatestQueueFile();
  await Player.inst.initializePlayer();
  await QueueController.inst.putLatestQueue();

  /// Clearing files cached by intents
  final cacheDirFiles = await getTemporaryDirectory().then((value) => value.listSync());
  for (final cf in cacheDirFiles) {
    if (cf is File) {
      cf.deleteSync();
    }
  }

  /// Recieving Initial Android Shared Intent.
  final intentfiles = await ReceiveSharingIntent.getInitialMedia();
  if (intentfiles.isNotEmpty) {
    final playedsuccessfully = await playExternalFile(intentfiles.map((e) => e.path).toList());
    if (!playedsuccessfully) {
      Get.snackbar(Language.inst.ERROR, Language.inst.COULDNT_PLAY_FILE);
    }
  }

  /// Listening to Android Shared Intents.
  /// Opening multiple files sometimes crashes the app.
  ReceiveSharingIntent.getMediaStream().listen((event) async {
    await playExternalFile(event.map((e) => e.path).toList());
  }, onError: (err) {
    Get.snackbar(Language.inst.ERROR, Language.inst.COULDNT_PLAY_FILE);
  });
  runApp(const MyApp());
}

/// returns [true] if played successfully.
Future<bool> playExternalFile(List<String> paths) async {
  final List<Track> trs = [];
  for (final p in paths) {
    final tr = await convertPathToTrack(p);
    if (tr != null) {
      trs.add(tr);
    }
  }
  if (trs.isNotEmpty) {
    await Player.inst.playOrPause(0, trs);
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Namida',
      theme: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, true),
      darkTheme: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, false),
      themeMode: SettingsController.inst.themeMode.value,
      translations: MyTranslation(),
      builder: (context, widget) {
        return ScrollConfiguration(behavior: const ScrollBehaviorModified(), child: widget!);
      },
      home: MainPageWrapper(),
    );
  }
}
