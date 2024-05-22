import 'dart:io';

import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class Folders {
  static final Folders inst = Folders._();
  Folders._();

  final Rxn<Folder> currentFolder = Rxn<Folder>();

  final RxList<Folder> currentFolderslist = <Folder>[].obs;

  List<Track> get currentTracks => currentFolder.value?.tracks ?? [];

  /// Even with this logic, root paths are invincible.
  final RxBool isHome = true.obs;

  /// Used for non-hierarchy.
  final RxBool isInside = false.obs;

  /// Highlights the track that is meant to be navigated to after calling [goToFolder].
  final RxnInt indexToScrollTo = RxnInt();

  double _latestScrollOffset = 0;

  /// Indicates wether the navigator can go back at this point.
  /// Returns true only if at home, otherwise will call [stepOut] and return false.
  bool onBackButton() {
    if (!isHome.value) {
      stepOut();
      return false;
    }
    return true;
  }

  void stepIn(Folder? folder, {Track? trackToScrollTo, double jumpTo = 0}) {
    if (folder == null || folder.path == '') {
      isHome.value = true;
      isInside.value = false;
      currentFolder.value = null;
      _scrollJump(jumpTo);
      return;
    }

    if (isHome.value != false) isHome.value = false;
    if (isInside.value != true) isInside.value = true;

    _saveScrollOffset();

    final dirInside = folder.getDirectoriesInside();

    currentFolderslist.value = dirInside;
    currentFolder.value = folder;

    if (trackToScrollTo != null) {
      indexToScrollTo.value = folder.tracks.indexOf(trackToScrollTo);
    }
    _scrollJump(jumpTo);
  }

  void stepOut() {
    Folder? folder;
    if (settings.enableFoldersHierarchy.value) {
      folder = currentFolder.value?.getParentFolder();
    }
    indexToScrollTo.value = null;
    stepIn(folder, jumpTo: _latestScrollOffset);
  }

  void onFirstLoad() {
    if (settings.enableFoldersHierarchy.value) {
      final startupPath = settings.defaultFolderStartupLocation.value;
      stepIn(Folder(startupPath));
    }
  }

  void onFoldersHierarchyChanged(bool enabled) {
    Folders.inst.isHome.value = true;
    Folders.inst.isInside.value = false;
  }

  void _saveScrollOffset() {
    try {
      _latestScrollOffset = LibraryTab.folders.scrollController.offset;
    } catch (_) {
      _latestScrollOffset = 0;
    }
  }

  void _scrollJump(double to) {
    if (LibraryTab.folders.scrollController.hasClients) {
      try {
        LibraryTab.folders.scrollController.jumpTo(to);
      } catch (_) {}
    }
  }

  /// Generates missing folders in between
  void onMapChanged(Map<Folder, List<Track>> map) {
    final newFolders = <MapEntry<Folder, List<Track>>>[];

    void recursiveIf(bool Function() fn) {
      if (fn()) recursiveIf(fn);
    }

    for (final k in map.keys) {
      final f = k.path.split(Platform.pathSeparator);
      f.removeLast();

      recursiveIf(() {
        if (f.length > 3) {
          final newPath = f.join(Platform.pathSeparator);
          if (kStoragePaths.contains(newPath)) {
            f.removeLast();
            return true;
          }
          if (map[Folder(newPath)] == null) {
            newFolders.add(MapEntry(Folder(newPath), []));
            f.removeLast();
            return true;
          }
        }
        return false;
      });
    }
    map.addEntries(newFolders);
    map.sortBy((e) => e.key.folderName.toLowerCase());
  }
}
