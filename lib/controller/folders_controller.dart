import 'package:get/get.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';

class Folders extends GetxController {
  static final Folders inst = Folders();

  final foldersMap = Indexer.inst.groupedFoldersMap;
  // final dirs = Indexer.inst.groupedFoldersMap.keys.toList();

  RxString currentPath = '/storage/emulated/0/'.obs;
  RxMap<String, List<Track>> currentFoldersMap = <String, List<Track>>{}.obs;
  RxList<Track> currentTracks = <Track>[].obs;

  stepIn([String? path]) {
    path ??= currentPath.value;
    currentPath.value = path;
    var filteredEntries = foldersMap.entries.where((entry) => entry.key.startsWith(currentPath) && entry.key.split('/').length == currentPath.split('/').length + 1).toList();

    // printError(info: filteredEntries.toString());
    currentFoldersMap.value = {for (var entry in filteredEntries) entry.key: entry.value};
    currentTracks.assignAll(foldersMap[currentPath.value]?.toList() ?? []);
  }

  stepOut() {
    printInfo(info: currentPath.value);

    final parts = currentPath.split('/');
    parts.removeLast();
    currentPath.value = parts.join('/');

    var filteredEntries = foldersMap.entries.where((entry) => entry.key.startsWith(currentPath) && entry.key.split('/').length == currentPath.split('/').length + 1).toList();
    if (filteredEntries.isEmpty) {
      filteredEntries = foldersMap.entries.where((entry) => entry.key.startsWith("/") && (entry.key.split('/').length == 4 || entry.key.split('/').length == 4)).toList();
    }

    final folderMapsNew = {for (var entry in filteredEntries) entry.key: entry.value};
    final tracksListNew = foldersMap[currentPath.value]?.toList() ?? [];
    printError(info: filteredEntries.toString());
    if (filteredEntries.isEmpty) {
      // stepOut();
    } else {
      currentFoldersMap.value = folderMapsNew;
      currentTracks.assignAll(tracksListNew);
    }
  }
}
