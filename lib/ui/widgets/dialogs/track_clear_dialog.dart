// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackClearDialog(Track track) {
  Get.dialog(
    CustomBlurryDialog(
      normalTitleStyle: true,
      title: Language.inst.CLEAR_TRACK_ITEM,
      child: Column(
        children: [
          CustomListTile(
            title: Language.inst.VIDEO_CACHE_FILE,
            icon: Broken.video,
            onTap: () async {
              final videoId = VideoController.inst.extractYTIDFromTrack(track);
              final allvideo = Directory(kVideosCachePath).listSync();
              for (final v in allvideo) {
                if (p.basename(v.path).startsWith(videoId)) {
                  await v.delete();
                }
              }
              Get.close(1);
              Player.inst.updateVideoPlayingState();
              VideoController.inst.youtubeLink.value = '';
            },
          ),
          CustomListTile(
            title: Language.inst.WAVEFORM_DATA,
            icon: Broken.sound,
            onTap: () async {
              Get.close(1);
              await File("$kWaveformDirPath${track.displayName}.wave").delete();
            },
          ),
          CustomListTile(
            title: Language.inst.ARTWORK,
            icon: Broken.image,
            onTap: () async {
              Get.close(1);
              await File("$kArtworksDirPath${track.displayName}.png").delete();
            },
          ),
          CustomListTile(
            title: Language.inst.ARTWORK_COMPRESSED,
            icon: Broken.gallery,
            onTap: () async {
              Get.close(1);
              await File("$kArtworksCompDirPath${track.displayName}.png").delete();
            },
          ),
        ],
      ),
    ),
  );
}
