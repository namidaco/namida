import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

class Folders {
  static final Folders inst = Folders();

  final folderslist = Indexer.inst.groupedFoldersList;

  final RxString currentPath = SettingsController.inst.defaultFolderStartupLocation.value.obs;
  final RxList<Folder> currentfolderslist = <Folder>[].obs;
  final RxList<Track> currentTracks = <Track>[].obs;

  /// Even with this logic, root paths are invincible.
  final RxBool isHome = true.obs;

  /// Used for non-hierarchy.
  final RxBool isInside = false.obs;

  void stepIn(Folder folder) {
    Folder? nextFolder;
    for (int i = 1; i < 100; i++) {
      nextFolder = folderslist.firstWhereOrNull((element) => element.path.startsWith(folder.path) && element.splits == folder.splits + i);
      if (nextFolder != null) {
        isHome.value = false;
        isInside.value = true;
        break;
      }
    }
    Iterable<Folder> currentFolders = [];
    currentFolders = folderslist.where((p0) {
      final f = p0.path.split('/');
      f.removeLast();
      return f.join('/') == folder.path && p0.splits == (nextFolder?.splits ?? 0);
    });
    final tracks = Folders.inst.folderslist.where((element) => element.path == folder.path).expand((entry) => entry.tracks).toList();

    /// in case nothing was found, probably due to multiple nesting.
    if (currentFolders.isEmpty && tracks.isEmpty) {
      currentFolders = folderslist.where((p0) {
        return p0.path.startsWith(folder.path) && p0.splits == (nextFolder?.splits ?? 0);
      });
    }

    currentPath.value = folder.path;
    currentfolderslist.assignAll(currentFolders);
    currentTracks.assignAll(tracks);

    sortFolderTracks();
  }

  stepOut() {
    isInside.value = false;
    if (!SettingsController.inst.enableFoldersHierarchy.value) {
      Folders.inst.currentTracks.clear();
    }
    final parts = currentPath.value.split('/');
    parts.removeLast();
    Folder? folder;
    folder = folderslist.firstWhereOrNull((element) => element.path == parts.join('/'));

    /// if inside one of the main paths.
    if (folder == null && (currentPath.value != kStoragePaths.first && currentPath.value != kStoragePaths.last)) {
      String? path;
      if (currentPath.value.startsWith(kStoragePaths.first)) {
        path = kStoragePaths.first;
      }
      if (currentPath.value.startsWith(kStoragePaths.last)) {
        path = kStoragePaths.last;
      }
      if (path != null) {
        folder = Folder(
          1,
          path.split('/').last,
          path,
          Folders.inst.folderslist.where((element) => element.path == path).expand((entry) => entry.tracks).toList(),
        );
      }
    }

    /// if still null
    if (folder == null) {
      isHome.value = true;
    } else {
      stepIn(folder);
    }
  }

  sortFolderTracks() {
    currentTracks.sort((a, b) => a.filename.compareTo(b.filename));

    currentfolderslist.sort((a, b) => a.folderName.compareTo(b.folderName));
    folderslist.sort((a, b) => a.folderName.compareTo(b.folderName));
  }
}
