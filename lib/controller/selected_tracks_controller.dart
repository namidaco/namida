import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class SelectedTracksController {
  static final SelectedTracksController inst = SelectedTracksController();

  final RxList<Track> selectedTracks = <Track>[].obs;
  final RxList<Track> currentAllTracks = <Track>[].obs;

  final RxBool isMenuMinimized = true.obs;
  final RxBool isExpanded = false.obs;

  final RxBool didInsertTracks = false.obs;

  final RxDouble bottomPadding = 0.0.obs;

  void selectOrUnselect(Track track, QueueSource queueSource) {
    if (selectedTracks.contains(track)) {
      selectedTracks.remove(track);
    } else {
      selectedTracks.add(track);
    }
    updateCurrentTracks(queueSource.toTracks());
    bottomPadding.value = selectedTracks.isEmpty ? 0.0 : 102.0;
    printInfo(info: "length: ${selectedTracks.length}");
  }

  void reorderTracks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = selectedTracks.removeAt(oldIndex);

    selectedTracks.insertSafe(newIndex, item);
  }

  void removeTrack(int index) {
    selectedTracks.removeAt(index);
  }

  void clearEverything() {
    selectedTracks.clear();
    isMenuMinimized.value = true;
    didInsertTracks.value = false;
    bottomPadding.value = 0.0;
  }

  void selectAllTracks() {
    selectedTracks.clear();
    selectedTracks.addAll(currentAllTracks.toList());
  }

  void updateCurrentTracks(List<Track> tracks) {
    currentAllTracks.clear();
    currentAllTracks.addAll(tracks);
  }

  void updatePageTracks(LibraryTab page) {
    if (page == LibraryTab.folders) {
      if (Folders.inst.currentTracks.isNotEmpty) {
        SelectedTracksController.inst.updateCurrentTracks(Folders.inst.currentTracks.toList());
      }
    }
    if (page == LibraryTab.tracks) {
      SelectedTracksController.inst.updateCurrentTracks(allTracksInLibrary);
    }
  }
}
