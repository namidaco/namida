import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

class Folders extends GetxController {
  static final Folders inst = Folders();

  final foldersMap = Indexer.inst.groupedFoldersMap;

  RxString currentPath = SettingsController.inst.defaultFolderStartupLocation.value.obs;
  RxMap<String, List<Track>> currentFoldersMap = <String, List<Track>>{}.obs;
  RxList<Track> currentTracks = <Track>[].obs;
  RxBool isHome = false.obs;
  RxBool isInside = false.obs;

  stepIn([String? path]) {
    path ??= currentPath.value;

    currentPath.value = path;
    List<MapEntry<String, List<Track>>> filteredEntries = [];
    if (isHome.value) {
      filteredEntries = foldersMap.entries.where((entry) => entry.key.startsWith(path!)).toList();
      isHome.value = false;
    } else {
      filteredEntries = foldersMap.entries.where((entry) => entry.key.startsWith(currentPath) && entry.key.split('/').length == currentPath.split('/').length + 1).toList();
    }

    printError(info: filteredEntries.toString());
    printError(info: isHome.toString());
    currentFoldersMap.value = {for (var entry in filteredEntries) entry.key: entry.value};
    currentTracks.assignAll(foldersMap[currentPath.value]?.toList() ?? []);
    if (currentPath.value == kStoragePaths.first && currentFoldersMap.length == 1 && currentTracks.isEmpty && !isHome.value) {
      stepIn();
    }
  }

  stepOut() {
    // printInfo(info: currentPath.value);

    final parts = currentPath.split('/');
    parts.removeLast();
    print(kStoragePaths.last);
    if (currentPath.value == kStoragePaths.first || currentPath.value == kStoragePaths.last) {
      isHome.value = true;
      return;
    } else {
      isHome.value = false;
    }
    currentPath.value = parts.join('/');

    var filteredEntries = foldersMap.entries.where((entry) => entry.key.startsWith(currentPath) && entry.key.split('/').length == currentPath.split('/').length + 1).toList();
    if (filteredEntries.isEmpty) {
      filteredEntries = foldersMap.entries.where((entry) => entry.key.startsWith("/") && (entry.key.split('/').length == 4 || entry.key.split('/').length == 4)).toList();
    }

    final folderMapsNew = {for (var entry in filteredEntries) entry.key: entry.value};
    final tracksListNew = foldersMap[currentPath.value]?.toList() ?? [];
    printError(info: filteredEntries.map((e) => e.key).toString());
    if (filteredEntries.isEmpty) {
      // stepOut();
    } else {
      currentFoldersMap.value = folderMapsNew;
      currentTracks.assignAll(tracksListNew);
    }
    if (currentFoldersMap.length == 1 && currentTracks.isEmpty && !isHome.value) {
      stepOut();
    }
  }
}
