import 'package:get/get.dart';
import 'package:namida/class/track.dart';

class SelectedTracksController extends GetxController {
  static SelectedTracksController inst = SelectedTracksController();
  RxList<Track> selectedTracks = <Track>[].obs;
  RxDouble bottomPadding = 102.0.obs;

  RxBool isMenuMinimized = true.obs;
  RxBool isExpanded = false.obs;

  SelectedTracksController() {
    selectedTracks.listen((st) {
      if (st.isNotEmpty) {
        bottomPadding.value = 102.0;
      } else {
        bottomPadding.value = 0.0;
      }
    });
  }

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

    selectedTracks.insert(newIndex, item);
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
