import 'package:get/get.dart';
import 'package:namida/controller/indexer_controller.dart';

class SelectedTracksController extends GetxController {
  static SelectedTracksController inst = SelectedTracksController();
  RxList<Track> selectedTracks = <Track>[].obs;
  RxDouble bottomPadding = 0.0.obs;

  RxBool isMenuMinimized = true.obs;
  RxBool isExpanded = false.obs;

  SelectedTracksController() {
    selectedTracks.listen((st) {
      print(st.length);
      if (st.isNotEmpty) {
        bottomPadding.value = 102.0;
      } else {
        bottomPadding.value = 0.0;
      }
    });
    // ever(selectedTracks, (value) {
    //   print(value.length);
    //   if (value.isNotEmpty) {
    //     bottomPadding.value = 92.0;
    //   } else {
    //     bottomPadding.value = 0.0;
    //   }
    // });
  }

  void selectOrUnselect(Track track) {
    if (selectedTracks.contains(track)) {
      selectedTracks.remove(track);
    } else {
      selectedTracks.add(track);
    }
    print("length: ${selectedTracks.length}");
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
