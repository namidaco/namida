import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/now_playing_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/core/translations/translations.dart';
import 'package:namida/ui/pages/homepage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  final sdkVersion = androidInfo.version.sdkInt;

  if (await Permission.storage.status.isDenied || await Permission.storage.status.isPermanentlyDenied) {
    final st = await Permission.storage.request();
    if (!st.isGranted) {
      SystemNavigator.pop();
    }
  }
  if (sdkVersion >= 33 && (await Permission.audio.status.isDenied || await Permission.audio.status.isPermanentlyDenied)) {
    print(sdkVersion);
    final st = await Permission.audio.request();
    if (!st.isGranted) {
      SystemNavigator.pop();
    }
  }

  // await Get.dialog(
  //   CustomBlurryDialog(
  //     title: Language.inst.STORAGE_PERMISSION,
  //     bodyText: Language.inst.STORAGE_PERMISSION_SUBTITLE,
  //     actions: [
  //       ElevatedButton(
  //         onPressed: () => Get.close(1),
  //         child: Text(Language.inst.CANCEL),
  //       ),
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

  await GetStorage.init();
  // if (!await Permission.manageExternalStorage.status.isGranted) {
  //   await Permission.manageExternalStorage.request();
  // }
  kAppDirectoryPath = await getApplicationDocumentsDirectory().then((value) => value.path);
  await Directory(kArtworksDirPath).create();
  await Directory(kArtworksCompDirPath).create();
  await Directory(kWaveformDirPath).create();

  print(kAudioFilesLength);

  final paths = await ExternalPath.getExternalStorageDirectories();
  kDirectoriesPaths = paths.map((path) => "$path/${ExternalPath.DIRECTORY_MUSIC}").toSet();
  kDirectoriesPaths.add('/storage/emulated/0/Download/');
  print(kDirectoriesPaths);
  // kDirectoriesPaths = paths.map((path) => path).toSet();
  print(kDirectoriesPaths);

  Get.put(() => SettingsController());
  Get.put(() => SelectedTracksController());
  final tfe = await File(kTracksFilePath).exists() && await File(kTracksFilePath).stat().then((value) => value.size != 0);
  if (tfe) {
    await Indexer.inst.prepareTracksFile(tfe);
  } else {
    Indexer.inst.prepareTracksFile(tfe);
  }
  // await Player.inst.initializePlayer();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Namida',
        theme: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, light: true),
        darkTheme: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, light: false),
        themeMode: SettingsController.inst.themeMode.value,
        translations: MyTranslation(),
        builder: (context, widget) {
          return ScrollConfiguration(behavior: const ScrollBehaviorModified(), child: widget!);
        },
        home: MediaQuery(
          data: MediaQueryData.fromWindow(WidgetsBinding.instance.window).copyWith(
            textScaleFactor: SettingsController.inst.fontScaleFactor.value,
          ),
          child: WillPopScope(
              onWillPop: () async => await Get.dialog(
                    CustomBlurryDialog(
                      bodyText: Language.inst.EXIT_APP_SUBTITLE,
                      title: Language.inst.EXIT_APP,
                      actions: [
                        ElevatedButton(
                          onPressed: () => Get.close(1),
                          child: Text(Language.inst.CANCEL),
                        ),
                        ElevatedButton(
                          onPressed: () => SystemNavigator.pop(),
                          child: Text(Language.inst.EXIT),
                        ),
                      ],
                    ),
                  ),
              child:

                  // return AnnotatedRegion<SystemUiOverlayStyle>(
                  //     value: SystemUiOverlayStyle(
                  //       // statusBarBrightness: Brightness.light,
                  //       // statusBarColor: Colors.grey.shade900,
                  //       // statusBarIconBrightness: Brightness.light,
                  //       systemNavigationBarColor: Colors.white.withAlpha(25),
                  //       systemNavigationBarDividerColor: Get.theme.bottomNavigationBarTheme.backgroundColor,
                  //       systemNavigationBarIconBrightness: Brightness.light,
                  //     ),
                  //     child:
                  HomePage()
              // );

              ),
        ),
        // child: AnimatedTheme(duration: Duration(seconds: 5), data: AppThemes().getAppTheme(CurrentColor.inst.color.value, light: false), child: HomePage())),
        // initialRoute: '/',
        // getPages: [
        //   GetPage(name: '/', page: () => HomePage()),
        //   GetPage(name: '/trackspage', page: () => TracksPage()),
        // ],
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
