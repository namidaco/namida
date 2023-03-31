import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/delete_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackClearDialog(List<Track> tracks) {
  final isSingle = tracks.length == 1;
  Get.dialog(
    CustomBlurryDialog(
      normalTitleStyle: true,
      icon: Broken.trash,
      title: isSingle ? Language.inst.CLEAR_TRACK_ITEM : Language.inst.CLEAR_TRACK_ITEM_MULTIPLE.replaceFirst('_NUMBER_', tracks.length.toString()),
      child: Column(
        children: [
          CustomListTile(
            title: isSingle ? Language.inst.VIDEO_CACHE_FILE : Language.inst.VIDEO_CACHE_FILES,
            icon: Broken.video,
            onTap: () async {
              await DeleteController.inst.deleteCachedVideos(tracks);
              Get.close(1);
            },
          ),
          CustomListTile(
            title: isSingle ? Language.inst.WAVEFORM_DATA : Language.inst.WAVEFORMS_DATA,
            icon: Broken.sound,
            onTap: () async {
              await DeleteController.inst.deleteWaveFormData(tracks);
              Get.close(1);
            },
          ),
          CustomListTile(
            title: Language.inst.LYRICS,
            icon: Broken.document,
            onTap: () async {
              await DeleteController.inst.deleteLyrics(tracks);
              Get.close(1);
            },
          ),
          CustomListTile(
            title: isSingle ? Language.inst.ARTWORK : Language.inst.ARTWORKS,
            icon: Broken.image,
            onTap: () async {
              await DeleteController.inst.deleteArtwork(tracks);
              Get.close(1);
            },
          ),
        ],
      ),
    ),
  );
}
