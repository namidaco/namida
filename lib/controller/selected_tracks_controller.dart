import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/extensions.dart';

class SelectedTracksController {
  static final SelectedTracksController inst = SelectedTracksController();

  final RxList<Track> selectedTracks = <Track>[].obs;
  final RxList<Track> currentAllTracks = <Track>[].obs;

  final RxBool isMenuMinimized = true.obs;
  final RxBool isExpanded = false.obs;

  void selectOrUnselect(Track track, List<Track> queue) {
    if (selectedTracks.contains(track)) {
      selectedTracks.remove(track);
    } else {
      selectedTracks.add(track);
    }
    currentAllTracks.assignAll(queue);
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
  }

  void selectAllTracks() {
    selectedTracks.clear();
    selectedTracks.addAll(currentAllTracks.toList());
  }
}
