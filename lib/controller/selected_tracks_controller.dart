import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class SelectedTracksController {
  static final SelectedTracksController inst = SelectedTracksController();

  final RxList<Track> selectedTracks = <Track>[].obs;

  List<Track> get currentAllTracks {
    if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      return Indexer.inst.trackSearchTemp.toList();
    }
    return NamidaNavigator.inst.currentWidgetStack.lastOrNull?.tracksInside ?? [];
  }

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
    selectedTracks.addAll(currentAllTracks);
    selectedTracks.removeDuplicates((element) => element.path);
  }
}
