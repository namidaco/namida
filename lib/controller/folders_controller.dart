import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

class Folders {
  static final Folders inst = Folders();

  // final RxString currentPath = SettingsController.inst.defaultFolderStartupLocation.value.obs;
  // List<Track> getTracks(String folderPath) => Indexer.inst.groupedFoldersMap[folderPath] ?? [];

  // List<String> get currentFoldersPaths => Indexer.inst.groupedFoldersMap.keys
  //     .where(
  //       (fld) => fld.startsWith(currentPath.value) && fld.split(Platform.pathSeparator).length == currentPath.value.split(Platform.pathSeparator).length + 1,
  //     )
  //     .toList();
  // List<Track> get currentTracks => getTracks(currentPath.value);

  // void stepIn(String toPath) {
  //   currentPath.value = toPath;
  // }

  final folderslist = Indexer.inst.groupedFoldersList;

  final RxString currentPath = SettingsController.inst.defaultFolderStartupLocation.value.obs;
  final RxList<Folder> currentfolderslist = <Folder>[].obs;
  final RxList<Track> currentTracks = <Track>[].obs;

  final ScrollController scrollController = ScrollController();

  /// Even with this logic, root paths are invincible.
  final RxBool isHome = true.obs;

  /// Used for non-hierarchy.
  final RxBool isInside = false.obs;

  void stepIn(Folder folder, {bool isMainStoragePath = false, bool comingFromStepOut = false}) {
    isHome.value = false;
    isInside.value = true;

    final tracks = isMainStoragePath
        ? folderslist
            .where(
              (element) => element.path == folder.path,
            )
            .expand((entry) => entry.tracks)
            .toList()
        : folder.tracks;

    Iterable<Folder> currentFolders = [];
    currentFolders = folderslist.where((p0) {
      final f = p0.path.split(Platform.pathSeparator);
      f.removeLast();
      return f.join(Platform.pathSeparator) == folder.path;
    });
    // currentFolders = folderslist.toList().where((fld) => fld.path.startsWith(folder.path) && fld.path.split(Platform.pathSeparator).length == folder.path.split(Platform.pathSeparator).length + 1);

    /// in case nothing was found, probably due to multiple nesting.
    if (currentFolders.isEmpty && tracks.isEmpty) {
      currentFolders = folderslist.where((p0) {
        return p0.path.startsWith(folder.path);
      });
    }
    // solving bug, should be solved from its roots but dk where the problem is
    // basically checks if no more folders and the length of tracks is sus
    if (currentFolders.isEmpty && tracks.length < folder.tracks.length) {
      currentFolders = folderslist.toList().where((fld) => fld.path.startsWith(folder.path));
    }

    currentPath.value = folder.path;
    currentfolderslist.assignAll(currentFolders);
    currentTracks.assignAll(tracks);
    sortFolderTracks();
    SelectedTracksController.inst.updateCurrentTracks(currentTracks.toList());

    if (!comingFromStepOut && currentFolders.length == 1 && tracks.isEmpty) {
      stepIn(currentFolders.first);
    }
    scrollController.jumpTo(0);
  }

  stepOut() {
    isInside.value = false;
    if (!SettingsController.inst.enableFoldersHierarchy.value) {
      Folders.inst.currentTracks.clear();
    }
    final parts = currentPath.value.split(Platform.pathSeparator);
    parts.removeLast();
    Folder? folder;
    folder = folderslist.firstWhereOrNull((element) => element.path == parts.join(Platform.pathSeparator));

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
          path,
          Folders.inst.folderslist.where((element) => element.path == path).expand((entry) => entry.tracks).toList(),
        );
      }
    }

    /// if still null
    if (folder == null) {
      isHome.value = true;
    } else {
      stepIn(folder, comingFromStepOut: true);
    }
  }

  sortFolderTracks() {
    currentTracks.sort((a, b) => a.filename.toLowerCase().compareTo(b.filename.toLowerCase()));

    currentfolderslist.sort((a, b) => a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase()));
    folderslist.sort((a, b) => a.folderName.toLowerCase().compareTo(b.folderName.toLowerCase()));
  }
}
