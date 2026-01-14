import 'dart:io';

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

  /// Granting Storage Permission.
  /// [request] will prompt dialog if not granted.
  Future<bool> requestStoragePermission({bool request = true}) async {
    if (Platform.isLinux || Platform.isWindows) return true;

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
    if (!(Platform.isAndroid || Platform.isIOS)) return true;

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

    if (!_shouldRequestManageAllFilesPermission) {
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
}
