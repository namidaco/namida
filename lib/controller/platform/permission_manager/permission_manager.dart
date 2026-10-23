import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

class PermissionManager {
  static final platform = PermissionManager._();
  PermissionManager._();

  static final _shouldRequestManageAllFilesPermission = NamidaFeaturesAvailablity.android11and_plus.resolve();

  Future<bool> hasManageExternalStoragePermission() async {
    if (!_shouldRequestManageAllFilesPermission) return true;
    return Permission.manageExternalStorage.isGranted;
  }

  Future<bool> requestNotificationsPermission() async {
    if (Platform.isIOS || Platform.isMacOS) return _requestNotificationsPermissionDarwin();
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {}
    return false;
  }

  /// permission_handler has no macOS side, flutter_local_notifications asks on both.
  Future<bool> _requestNotificationsPermissionDarwin() async {
    final plugin = FlutterLocalNotificationsPlugin();
    try {
      final bool? granted;
      if (Platform.isIOS) {
        final ios = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        granted = await ios?.requestPermissions(alert: true, sound: true);
      } else {
        final macos = plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
        granted = await macos?.requestPermissions(alert: true, sound: true);
      }
      return granted == true;
    } catch (_) {}
    return false;
  }

  /// Granting Storage Permission.
  /// [request] will prompt dialog if not granted.
  Future<bool> requestStoragePermission({bool request = true}) async {
    if (NamidaFeaturesVisibility.isStoragePermissionNotRequired) return true;

    bool granted = false;

    final permissionsToRequest = <Permission>[];
    if (NamidaDeviceInfo.useOldStoragePermission) {
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
    if (!Platform.isAndroid) return true;

    final granted = await Permission.ignoreBatteryOptimizations.isGranted;
    if (granted) return true;
    if (!settings.canAskForBatteryOptimizations.value) return false;

    snackyy(
      message: lang.ignoreBatteryOptimizationsSubtitle,
      displayDuration: SnackDisplayDuration.eternal,
      top: false,
      isError: true,
      button: SnackbarButton(
        text: lang.dontAskAgain,
        function: () => settings.canAskForBatteryOptimizations.save(false),
      ),
    );
    await Future.delayed(const Duration(seconds: 1));
    final p = await Permission.ignoreBatteryOptimizations.request();
    return p.isGranted;
  }

  Future<bool> requestManageStoragePermission({bool request = true, bool showError = true, required String? directoryToCreate}) async {
    Future<void> createDir() async {
      if (directoryToCreate == null) return;
      final dir = Directory(directoryToCreate);
      if (!await dir.exists()) await dir.create(recursive: true);
    }

    if (!_shouldRequestManageAllFilesPermission) {
      await createDir();
      return true;
    }

    if (request && !await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }

    if (!await Permission.manageExternalStorage.isGranted || await Permission.manageExternalStorage.isDenied) {
      if (showError) snackyy(title: lang.storagePermissionDenied, message: lang.storagePermissionDeniedSubtitle, isError: true);
      return false;
    }
    await createDir();
    return true;
  }
}
