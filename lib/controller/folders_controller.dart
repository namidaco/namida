import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';

class Folders {
  static final Folders inst = Folders();

  final Rxn<Folder> currentFolder = Rxn<Folder>();

  final RxList<Folder> currentFolderslist = <Folder>[].obs;
  List<Track> get currentTracks => currentFolder.value?.tracks ?? [];

  final ScrollController scrollController = ScrollController();

  /// Even with this logic, root paths are invincible.
  final RxBool isHome = true.obs;

  /// Used for non-hierarchy.
  final RxBool isInside = false.obs;

  void stepIn(Folder? folder, {bool isMainStoragePath = false}) {
    if (folder == null || folder.path == '') {
      isHome.value = true;
      isInside.value = false;
      currentFolder.value = null;
      return;
    }
    isHome.value = false;
    isInside.value = true;

    final dirInside = folder.getDirectoriesInside();

    if (dirInside.length == 1 && folder.tracks.isEmpty) {
      stepIn(dirInside.first);
      return;
    }

    currentFolderslist
      ..clear()
      ..addAll(dirInside);

    currentFolder.value = folder;
  }

  void stepOut() {
    Folder? folder;
    if (SettingsController.inst.enableFoldersHierarchy.value) {
      folder = currentFolder.value?.getParentFolder(fullyFunctional: true);
    }
    stepIn(folder);
  }

  void onFirstLoad() {
    stepIn(Folder(SettingsController.inst.defaultFolderStartupLocation.value));
  }
}
