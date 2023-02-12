import 'package:get/get.dart';
import 'package:namida/controller/indexer_controller.dart';

class FoldersController extends GetxController {
  static FoldersController inst = FoldersController();
  // RxList<Track> foldersTracks = <Track>[].obs;

  RxBool displayTracks = false.obs;

  @override
  void onClose() {
    Get.delete();
    super.onClose();
  }
}
