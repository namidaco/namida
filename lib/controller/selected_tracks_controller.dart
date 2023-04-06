import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/extensions.dart';

class SelectedTracksController extends GetxController {
  static SelectedTracksController inst = SelectedTracksController();
  final RxList<Track> selectedTracks = <Track>[].obs;
  final RxList<Track> currentAllTracks = <Track>[].obs;

  final RxBool isMenuMinimized = true.obs;
  final RxBool isExpanded = false.obs;

  void selectOrUnselect(Track track) {
    if (selectedTracks.contains(track)) {
      selectedTracks.remove(track);
    } else {
      selectedTracks.add(track);
    }
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

  @override
  void onClose() {
    Get.delete();
    super.onClose();
  }
}
